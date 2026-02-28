defmodule Pipeline.PipelineCoordinator do
  require Logger
  alias Pipeline.{Repo, ContentValidator, ReaderApiClient}
  alias Pipeline.Schemas.{Article, WorkflowCost}
  alias Pipeline.Agents.RouterAgent

  def process_url(url, opts \\ []) do
    retry = Keyword.get(opts, :retry, false)
    strategy = Keyword.get(opts, :strategy, :direct)

    with {:ok, article} <- create_or_get_article(url, retry),
         {:ok, content} <- fetch_article_content(url, strategy),
         {:ok, article} <- update_article_success(article, content, strategy) do
      RouterAgent.process_article(article.id)

      Phoenix.PubSub.broadcast(
        Pipeline.PubSub,
        "article:fetch_success",
        {:fetch_success, article.id}
      )

      {:ok, article}
    else
      {:error, error_type, details} ->
        handle_fetch_error(url, error_type, details, retry)
    end
  end

  defp create_or_get_article(url, retry) do
    case Repo.get_by(Article, url: url) do
      nil ->
        %Article{}
        |> Article.changeset(%{
          url: url,
          status: "fetching",
          last_fetch_attempt: DateTime.utc_now()
        })
        |> Repo.insert()

      article when retry ->
        article
        |> Article.changeset(%{
          retry_count: article.retry_count + 1,
          last_fetch_attempt: DateTime.utc_now(),
          status: "retrying"
        })
        |> Repo.update()

      article ->
        {:ok, article}
    end
  end

  defp fetch_article_content(url, strategy) do
    case apply_fetch_strategy(url, strategy) do
      {:ok, html} ->
        content = extract_text_from_html(html)

        case ContentValidator.validate(content, url) do
          {:ok, validated_content} -> {:ok, validated_content}
          {:error, error_type, details} -> {:error, error_type, details}
        end

      {:error, error_type, details} ->
        {:error, error_type, details}
    end
  end

  defp apply_fetch_strategy(url, :direct) do
    case HTTPoison.get(url, [], timeout: 30_000, recv_timeout: 30_000) do
      {:ok, %{status_code: 200, body: body}} -> {:ok, body}
      {:ok, %{status_code: 404}} -> {:error, :not_found, "Page not found"}
      {:ok, %{status_code: 403}} -> {:error, :forbidden, "Access forbidden"}
      _ -> {:error, :fetch_failed, "HTTP error"}
    end
  end

  defp apply_fetch_strategy(url, :reader_api) do
    case ReaderApiClient.fetch(url) do
      {:ok, %{content: content}} -> {:ok, content}
      _ -> {:error, :reader_api_failed, "Reader API failed"}
    end
  end

  defp extract_text_from_html(html) do
    html
    |> String.replace(~r/<script.*?<\/script>/s, "")
    |> String.replace(~r/<style.*?<\/style>/s, "")
    |> String.replace(~r/<[^>]+>/, " ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp update_article_success(article, content, strategy) do
    title = content |> String.split("\n") |> List.first() |> String.slice(0..100)

    article
    |> Article.changeset(%{
      content: content,
      title: title,
      status: "fetched",
      fetch_strategy: to_string(strategy)
    })
    |> Repo.update()
  end

  defp handle_fetch_error(url, error_type, details, _is_retry) do
    article =
      case Repo.get_by(Article, url: url) do
        nil -> %Article{} |> Article.changeset(%{url: url}) |> Repo.insert!()
        existing -> existing
      end

    retry_suggestion = ContentValidator.suggest_retry_strategy(error_type)

    updated =
      article
      |> Article.changeset(%{status: "fetch_failed", fetch_error: to_string(error_type)})
      |> Repo.update!()

    Phoenix.PubSub.broadcast(
      Pipeline.PubSub,
      "article:fetch_failed",
      {:fetch_failed, updated.id, error_type, retry_suggestion}
    )

    {:error, error_type, details, retry_suggestion}
  end

  def retry_article(article_id) do
    article = Repo.get!(Article, article_id)

    if Article.can_retry?(article) do
      process_url(article.url, retry: true, strategy: :reader_api)
    else
      {:error, :max_retries_reached}
    end
  end

  def calculate_workflow_cost(article_id) do
    article =
      Repo.get!(Article, article_id)
      |> Repo.preload([
        :tier_1_classification,
        :tier_2_quick_scan,
        :tier_2_5_actionability,
        :tier_3_deep_analysis
      ])

    get_cost = fn field ->
      if field, do: field.api_cost || Decimal.new(0), else: Decimal.new(0)
    end

    costs = [
      get_cost.(article.tier_1_classification),
      get_cost.(article.tier_2_quick_scan),
      get_cost.(article.tier_2_5_actionability),
      get_cost.(article.tier_3_deep_analysis)
    ]

    total = Enum.reduce(costs, Decimal.new(0), &Decimal.add/2)

    %WorkflowCost{}
    |> WorkflowCost.changeset(%{
      article_id: article_id,
      total_cost: total,
      tier_1_cost: Enum.at(costs, 0),
      tier_2_cost: Enum.at(costs, 1),
      tier_2_5_cost: Enum.at(costs, 2),
      tier_3_cost: Enum.at(costs, 3),
      completed_at: DateTime.utc_now()
    })
    |> Repo.insert()
  end

  def get_article_analysis(article_id) do
    Repo.get!(Article, article_id)
    |> Repo.preload([
      :tier_1_classification,
      :tier_2_quick_scan,
      :tier_2_5_actionability,
      :tier_3_deep_analysis,
      :workflow_cost
    ])
  end
end
