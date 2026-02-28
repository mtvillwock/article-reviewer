defmodule Pipeline.Schemas.WorkflowCost do
  use Ecto.Schema
  import Ecto.Changeset

  schema "workflow_costs" do
    field :total_cost, :decimal
    field :tier_1_cost, :decimal
    field :tier_2_cost, :decimal
    field :tier_2_5_cost, :decimal
    field :tier_3_cost, :decimal
    field :total_tokens, :integer
    field :completed_at, :utc_datetime
    belongs_to :article, Pipeline.Schemas.Article
    timestamps()
  end

  def changeset(cost, attrs) do
    cost
    |> cast(attrs, [
      :article_id,
      :total_cost,
      :tier_1_cost,
      :tier_2_cost,
      :tier_2_5_cost,
      :tier_3_cost,
      :total_tokens,
      :completed_at
    ])
    |> validate_required([:article_id, :total_cost])
    |> unique_constraint(:article_id)
    |> foreign_key_constraint(:article_id)
  end
end
