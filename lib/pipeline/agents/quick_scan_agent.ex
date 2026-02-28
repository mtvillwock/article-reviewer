defmodule Pipeline.Agents.QuickScanAgent do
  use GenServer
  require Logger
  alias Pipeline.{Repo, LLM.AnthropicClient}
  alias Pipeline.Schemas.{Article, Tier2QuickScan}

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  def process_article(article_id), do: GenServer.cast(__MODULE__, {:process, article_id})

  @impl true
  def init(_opts) do
    Phoenix.PubSub.subscribe(Pipeline.PubSub, "article:tier_1_complete")
    Logger.info("QuickScanAgent started")
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:process, article_id}, state) do
    Task.start(fn -> do_process(article_id) end)
    {:noreply, state}
  end

  @impl true
  def handle_info({:tier_1_complete, article_id, "QUICK_SCAN"}, state) do
    process_article(article_id)
    {:noreply, state}
  end

  @impl true
  def handle_info({:tier_1_complete, article_id, "SKIP"}, state) do
    article = Repo.get!(Article, article_id)
    article |> Article.changeset(%{status: "skipped"}) |> Repo.update!()
    {:noreply, state}
  end

  defp do_process(article_id) do
    article = Repo.get!(Article, article_id) |> Repo.preload(:tier_1_classification)

    prompt =
      File.read!("priv/prompts/tier_2_quick_scan.txt")
      |> String.replace("{{TITLE}}", article.title || "Untitled")
      |> String.replace("{{CONTENT}}", String.slice(article.content, 0..8000))
      |> String.replace("{{CONTENT_TYPE}}", article.tier_1_classification.content_type)
      |> String.replace("{{COMPLEXITY}}", article.tier_1_classification.complexity)

    start_time = System.monotonic_time(:millisecond)

    case AnthropicClient.create_message(
           model: "claude-sonnet-4-5-20250929",
           messages: [%{role: "user", content: prompt}],
           max_tokens: 2000
         ) do
      {:ok, response} ->
        processing_time = System.monotonic_time(:millisecond) - start_time
        handle_success(article_id, response, processing_time)

      {:error, reason} ->
        Logger.error("QuickScanAgent failed: #{inspect(reason)}")
    end
  end

  defp handle_success(article_id, response, processing_time) do
    text = response["content"] |> Enum.find(&(&1["type"] == "text")) |> Map.get("text", "")
    scan = parse_scan(text)

    usage = response["usage"]

    cost =
      AnthropicClient.calculate_cost(
        "claude-sonnet-4-5-20250929",
        usage["input_tokens"],
        usage["output_tokens"]
      )

    %Tier2QuickScan{}
    |> Tier2QuickScan.changeset(%{
      article_id: article_id,
      routing_decision: scan["routing_decision"],
      confidence: scan["confidence"],
      trigger_criteria: scan["trigger_criteria"] || [],
      key_claims: scan["key_claims"] || [],
      justification: scan["justification"],
      estimated_analysis_value: scan["estimated_analysis_value"],
      api_cost: cost,
      tokens_used: usage["input_tokens"] + usage["output_tokens"],
      processing_time_ms: processing_time
    })
    |> Repo.insert!(on_conflict: :replace_all, conflict_target: :article_id)

    Logger.info("QuickScanAgent completed: #{scan["routing_decision"]}")

    case scan["routing_decision"] do
      "ACTIONABILITY_LAYER" ->
        Phoenix.PubSub.broadcast(
          Pipeline.PubSub,
          "article:tier_2_5_needed",
          {:tier_2_5_needed, article_id}
        )

      "DEEP_ANALYSIS" ->
        Phoenix.PubSub.broadcast(
          Pipeline.PubSub,
          "article:tier_3_needed",
          {:tier_3_needed, article_id}
        )

      "SKIP" ->
        article = Repo.get!(Article, article_id)
        article |> Article.changeset(%{status: "skipped"}) |> Repo.update!()

        Phoenix.PubSub.broadcast(
          Pipeline.PubSub,
          "article:complete",
          {:article_complete, article_id}
        )
    end
  end

  defp parse_scan(text) do
    json_text =
      text
      |> String.replace(~r/```json\n?/, "")
      |> String.replace(~r/```\n?/, "")
      |> String.trim()

    case Jason.decode(json_text) do
      {:ok, parsed} ->
        parsed

      {:error, _} ->
        %{"routing_decision" => "SKIP", "confidence" => 50, "justification" => "Parse error"}
    end
  end
end
