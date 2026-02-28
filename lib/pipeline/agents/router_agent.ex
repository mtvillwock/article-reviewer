defmodule Pipeline.Agents.RouterAgent do
  use GenServer
  require Logger
  alias Pipeline.{Repo, LLM.AnthropicClient}
  alias Pipeline.Schemas.{Article, Tier1Classification}

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  def process_article(article_id), do: GenServer.cast(__MODULE__, {:process, article_id})

  @impl true
  def init(_opts) do
    Phoenix.PubSub.subscribe(Pipeline.PubSub, "article:fetch_success")
    Logger.info("RouterAgent started")
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:process, article_id}, state) do
    Task.start(fn -> do_process(article_id) end)
    {:noreply, state}
  end

  @impl true
  def handle_info({:fetch_success, article_id}, state) do
    process_article(article_id)
    {:noreply, state}
  end

  defp do_process(article_id) do
    article = Repo.get!(Article, article_id) |> Repo.preload(:tier_1_classification)

    # Skip if already classified
    if article.tier_1_classification do
      Logger.info("Article #{article_id} already classified, broadcasting existing decision")

      Phoenix.PubSub.broadcast(
        Pipeline.PubSub,
        "article:tier_1_complete",
        {:tier_1_complete, article_id, article.tier_1_classification.routing_decision}
      )
    else
      article |> Article.changeset(%{status: "processing"}) |> Repo.update!()

      prompt =
        File.read!("priv/prompts/tier_1_router.txt")
        |> String.replace("{{TITLE}}", article.title || "Untitled")
        |> String.replace("{{CONTENT}}", String.slice(article.content, 0..4000))

      start_time = System.monotonic_time(:millisecond)

      case AnthropicClient.create_message(
             model: "claude-haiku-4-5-20251001",
             messages: [%{role: "user", content: prompt}],
             max_tokens: 1000
           ) do
        {:ok, response} ->
          processing_time = System.monotonic_time(:millisecond) - start_time
          handle_success(article_id, response, processing_time)

        {:error, reason} ->
          Logger.error("RouterAgent failed: #{inspect(reason)}")
      end
    end
  end

  defp handle_success(article_id, response, processing_time) do
    text = response["content"] |> Enum.find(&(&1["type"] == "text")) |> Map.get("text", "")
    classification = parse_classification(text)

    usage = response["usage"]

    cost =
      AnthropicClient.calculate_cost(
        "claude-haiku-4-5-20251001",
        usage["input_tokens"],
        usage["output_tokens"]
      )

    %Tier1Classification{}
    |> Tier1Classification.changeset(%{
      article_id: article_id,
      content_type: classification["content_type"],
      complexity: classification["complexity"],
      novelty: classification["novelty"],
      operational_value: classification["operational_value"],
      routing_decision: classification["routing_decision"],
      reasoning: classification["reasoning"],
      api_cost: cost,
      tokens_used: usage["input_tokens"] + usage["output_tokens"],
      processing_time_ms: processing_time
    })
    |> Repo.insert!(on_conflict: :replace_all, conflict_target: :article_id)

    Logger.info(
      "RouterAgent completed for article #{article_id}: #{classification["routing_decision"]}"
    )

    Phoenix.PubSub.broadcast(
      Pipeline.PubSub,
      "article:tier_1_complete",
      {:tier_1_complete, article_id, classification["routing_decision"]}
    )
  end

  defp parse_classification(text) do
    json_text =
      text
      |> String.replace(~r/```json\n?/, "")
      |> String.replace(~r/```\n?/, "")
      |> String.trim()

    case Jason.decode(json_text) do
      {:ok, parsed} ->
        parsed

      {:error, _} ->
        Logger.warn("Failed to parse classification JSON")

        %{
          "routing_decision" => "QUICK_SCAN",
          "complexity" => "moderate",
          "content_type" => "unknown",
          "novelty" => "moderate",
          "operational_value" => "medium",
          "reasoning" => "Parse error"
        }
    end
  end
end
