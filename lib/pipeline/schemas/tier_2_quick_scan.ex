defmodule Pipeline.Schemas.Tier2QuickScan do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tier_2_quick_scans" do
    field :routing_decision, :string
    field :confidence, :integer
    field :trigger_criteria, {:array, :string}
    field :key_claims, {:array, :string}
    field :justification, :string
    field :estimated_analysis_value, :string
    field :api_cost, :decimal
    field :tokens_used, :integer
    field :processing_time_ms, :integer
    belongs_to :article, Pipeline.Schemas.Article
    timestamps()
  end

  def changeset(scan, attrs) do
    scan
    |> cast(attrs, [
      :article_id,
      :routing_decision,
      :confidence,
      :trigger_criteria,
      :key_claims,
      :justification,
      :estimated_analysis_value,
      :api_cost,
      :tokens_used,
      :processing_time_ms
    ])
    |> validate_required([:article_id, :routing_decision])
    |> unique_constraint(:article_id)
    |> foreign_key_constraint(:article_id)
  end
end
