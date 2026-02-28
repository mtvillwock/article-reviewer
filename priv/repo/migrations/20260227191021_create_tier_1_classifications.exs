defmodule Pipeline.Repo.Migrations.CreateTier1Classifications do
  use Ecto.Migration

  def change do
    create table(:tier_1_classifications) do
      add(:article_id, references(:articles, on_delete: :delete_all), null: false)
      add(:content_type, :string)
      add(:complexity, :string)
      add(:novelty, :string)
      add(:operational_value, :string)
      add(:routing_decision, :string)
      add(:reasoning, :text)
      add(:api_cost, :decimal, precision: 10, scale: 6)
      add(:tokens_used, :integer)
      add(:processing_time_ms, :integer)
      timestamps()
    end

    create(unique_index(:tier_1_classifications, [:article_id]))
  end
end
