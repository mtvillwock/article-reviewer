defmodule Pipeline.Agents.ActionabilityAgent do
  use GenServer
  require Logger
  alias Pipeline.{Repo, LLM.AnthropicClient, PipelineCoordinator}
  alias Pipeline.Schemas.{Article, Tier25Actionability}

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  def process_article(article_id), do: GenServer.cast(__MODULE__, {:process, article_id})

  @impl true
  def init(_opts) do
    Phoenix.PubSub.subscribe(Pipeline.PubSub, "article:tier_2_5_needed")
    Logger.info("ActionabilityAgent started")
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:process, article_id}, state) do
    Task.start(fn -> do_process(article_id) end)
    {:noreply, state}
  end

  @impl true
  def handle_info({:tier_2_5_needed, article_id}, state) do
    process_article(article_id)
    {:noreply, state}
  end

  defp do_process(article_id) do
    article = Repo.get!(Article, article_id)

    prompt =
      File.read!("priv/prompts/tier_2_5_actionability.txt")
      |> String.replace("{{TITLE}}", article.title || "Untitled")
      |> String.replace("{{CONTENT}}", article.content)

    start_time = System.monotonic_time(:millisecond)

    case AnthropicClient.create_message(
           model: "claude-sonnet-4-5-20250929",
           messages: [%{role: "user", content: prompt}],
           max_tokens: 4000
         ) do
      {:ok, response} ->
        processing_time = System.monotonic_time(:millisecond) - start_time
        text = response["content"] |> Enum.find(&(&1["type"] == "text")) |> Map.get("text", "")
        usage = response["usage"]

        cost =
          AnthropicClient.calculate_cost(
            "claude-sonnet-4-5-20250929",
            usage["input_tokens"],
            usage["output_tokens"]
          )

        %Tier25Actionability{}
        |> Tier25Actionability.changeset(%{
          article_id: article_id,
          one_sentence_essence: text,
          api_cost: cost,
          tokens_used: usage["input_tokens"] + usage["output_tokens"],
          processing_time_ms: processing_time
        })
        |> Repo.insert!(on_conflict: :replace_all, conflict_target: :article_id)

        article |> Article.changeset(%{status: "complete"}) |> Repo.update!()
        PipelineCoordinator.calculate_workflow_cost(article_id)

        Logger.info("ActionabilityAgent completed for article #{article_id}")

        Phoenix.PubSub.broadcast(
          Pipeline.PubSub,
          "article:complete",
          {:article_complete, article_id}
        )

      {:error, reason} ->
        Logger.error("ActionabilityAgent failed: #{inspect(reason)}")
    end
  end
end
