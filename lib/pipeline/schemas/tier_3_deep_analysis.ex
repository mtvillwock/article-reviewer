defmodule Pipeline.Schemas.Tier3DeepAnalysis do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tier_3_deep_analyses" do
    field :executive_summary, :string
    field :extracted_frameworks, :string
    field :critical_assessment, :string
    field :extract_items, {:array, :string}
    field :discard_items, {:array, :string}
    field :reframe_items, :map
    field :practical_guidance, :string
    field :final_assessment, :string
    field :api_cost, :decimal
    field :tokens_used, :integer
    field :processing_time_ms, :integer
    belongs_to :article, Pipeline.Schemas.Article
    timestamps()
  end

  def changeset(analysis, attrs) do
    analysis
    |> cast(attrs, [
      :article_id,
      :executive_summary,
      :extracted_frameworks,
      :critical_assessment,
      :extract_items,
      :discard_items,
      :reframe_items,
      :practical_guidance,
      :final_assessment,
      :api_cost,
      :tokens_used,
      :processing_time_ms
    ])
    |> validate_required([:article_id])
    |> unique_constraint(:article_id)
    |> foreign_key_constraint(:article_id)
  end
end
