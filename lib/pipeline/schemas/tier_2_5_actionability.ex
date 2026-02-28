defmodule Pipeline.Schemas.Tier25Actionability do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tier_2_5_actionability" do
    field :one_sentence_essence, :string
    field :quick_start_checklist, :string
    field :implementation_template, :string
    field :integration_guide, :string
    field :failure_modes, :string
    field :success_indicators, :string
    field :iteration_triggers, :string
    field :api_cost, :decimal
    field :tokens_used, :integer
    field :processing_time_ms, :integer
    belongs_to :article, Pipeline.Schemas.Article
    timestamps()
  end

  def changeset(actionability, attrs) do
    actionability
    |> cast(attrs, [
      :article_id,
      :one_sentence_essence,
      :quick_start_checklist,
      :implementation_template,
      :integration_guide,
      :failure_modes,
      :success_indicators,
      :iteration_triggers,
      :api_cost,
      :tokens_used,
      :processing_time_ms
    ])
    |> validate_required([:article_id])
    |> unique_constraint(:article_id)
    |> foreign_key_constraint(:article_id)
  end
end
