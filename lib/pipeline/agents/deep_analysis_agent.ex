defmodule Pipeline.Agents.DeepAnalysisAgent do
  use GenServer
  require Logger
  alias Pipeline.{Repo, LLM.AnthropicClient, PipelineCoordinator}
  alias Pipeline.Schemas.{Article, Tier3DeepAnalysis}

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  def process_article(article_id), do: GenServer.cast(__MODULE__, {:process, article_id})

  @impl true
  def init(_opts) do
    Phoenix.PubSub.subscribe(Pipeline.PubSub, "article:tier_3_needed")
    Logger.info("DeepAnalysisAgent started")
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:process, article_id}, state) do
    Task.start(fn -> do_process(article_id) end)
    {:noreply, state}
  end

  @impl true
  def handle_info({:tier_3_needed, article_id}, state) do
    process_article(article_id)
    {:noreply, state}
  end

  defp do_process(article_id) do
    article = Repo.get!(Article, article_id) |> Repo.preload(:tier_1_classification)

    prompt =
      File.read!("priv/prompts/tier_3_deep_analysis.txt")
      |> String.replace("{{TITLE}}", article.title || "Untitled")
      |> String.replace("{{CONTENT}}", article.content)
      |> String.replace("{{CONTENT_TYPE}}", article.tier_1_classification.content_type)

    start_time = System.monotonic_time(:millisecond)

    case AnthropicClient.create_message(
           model: "claude-opus-4-5-20251101",
           messages: [%{role: "user", content: prompt}],
           max_tokens: 16000
         ) do
      {:ok, response} ->
        processing_time = System.monotonic_time(:millisecond) - start_time
        text = response["content"] |> Enum.find(&(&1["type"] == "text")) |> Map.get("text", "")
        usage = response["usage"]

        cost =
          AnthropicClient.calculate_cost(
            "claude-opus-4-5-20251101",
            usage["input_tokens"],
            usage["output_tokens"]
          )

        %Tier3DeepAnalysis{}
        |> Tier3DeepAnalysis.changeset(%{
          article_id: article_id,
          executive_summary: text,
          api_cost: cost,
          tokens_used: usage["input_tokens"] + usage["output_tokens"],
          processing_time_ms: processing_time
        })
        |> Repo.insert!(on_conflict: :replace_all, conflict_target: :article_id)

        article |> Article.changeset(%{status: "complete"}) |> Repo.update!()
        PipelineCoordinator.calculate_workflow_cost(article_id)

        Logger.info("DeepAnalysisAgent completed for article #{article_id}")

        Phoenix.PubSub.broadcast(
          Pipeline.PubSub,
          "article:complete",
          {:article_complete, article_id}
        )

      {:error, reason} ->
        Logger.error("DeepAnalysisAgent failed: #{inspect(reason)}")
    end
  end
end
