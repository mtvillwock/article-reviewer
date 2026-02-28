defmodule Pipeline.Schemas.Article do
  use Ecto.Schema
  import Ecto.Changeset

  schema "articles" do
    field :url, :string
    field :title, :string
    field :content, :string
    field :status, :string, default: "pending"
    field :fetch_error, :string
    field :fetch_error_details, :string
    field :retry_count, :integer, default: 0
    field :last_fetch_attempt, :utc_datetime
    field :fetch_strategy, :string

    has_one :tier_1_classification, Pipeline.Schemas.Tier1Classification
    has_one :tier_2_quick_scan, Pipeline.Schemas.Tier2QuickScan
    has_one :tier_2_5_actionability, Pipeline.Schemas.Tier25Actionability
    has_one :tier_3_deep_analysis, Pipeline.Schemas.Tier3DeepAnalysis
    has_one :workflow_cost, Pipeline.Schemas.WorkflowCost

    timestamps()
  end

  def changeset(article, attrs) do
    article
    |> cast(attrs, [
      :url,
      :title,
      :content,
      :status,
      :fetch_error,
      :fetch_error_details,
      :retry_count,
      :last_fetch_attempt,
      :fetch_strategy
    ])
    |> validate_required([:url])
    |> unique_constraint(:url)
    |> validate_inclusion(:status, [
      "pending",
      "fetching",
      "retrying",
      "fetched",
      "fetch_failed",
      "processing",
      "complete",
      "skipped"
    ])
    |> validate_number(:retry_count, greater_than_or_equal_to: 0, less_than_or_equal_to: 3)
  end

  def can_retry?(%__MODULE__{} = article) do
    article.retry_count < 3 and article.fetch_error != nil and
      article.fetch_error not in ["not_found", "forbidden"]
  end

  def format_error(%__MODULE__{fetch_error: nil}), do: nil

  def format_error(%__MODULE__{fetch_error: error}) do
    case error do
      "javascript_required" -> "Content requires JavaScript to render"
      "insufficient_content" -> "Content too short or missing"
      "timeout" -> "Request timed out"
      "forbidden" -> "Access forbidden (403)"
      "not_found" -> "Article not found (404)"
      "parse_error" -> "Unable to parse content"
      _ -> "Unknown error"
    end
  end
end
