defmodule Pipeline.Schemas.Tier1Classification do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tier_1_classifications" do
    field :content_type, :string
    field :complexity, :string
    field :novelty, :string
    field :operational_value, :string
    field :routing_decision, :string
    field :reasoning, :string
    field :api_cost, :decimal
    field :tokens_used, :integer
    field :processing_time_ms, :integer
    belongs_to :article, Pipeline.Schemas.Article
    timestamps()
  end

  def changeset(classification, attrs) do
    classification
    |> cast(attrs, [
      :article_id,
      :content_type,
      :complexity,
      :novelty,
      :operational_value,
      :routing_decision,
      :reasoning,
      :api_cost,
      :tokens_used,
      :processing_time_ms
    ])
    |> validate_required([:article_id, :routing_decision])
    |> unique_constraint(:article_id)
    |> foreign_key_constraint(:article_id)
  end
end
