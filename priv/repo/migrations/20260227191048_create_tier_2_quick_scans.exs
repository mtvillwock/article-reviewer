defmodule Pipeline.Repo.Migrations.CreateTier2QuickScans do
  use Ecto.Migration

  def change do
    create table(:tier_2_quick_scans) do
      add(:article_id, references(:articles, on_delete: :delete_all), null: false)
      add(:routing_decision, :string)
      add(:confidence, :integer)
      add(:trigger_criteria, {:array, :string})
      add(:key_claims, {:array, :string})
      add(:justification, :text)
      add(:estimated_analysis_value, :string)
      add(:api_cost, :decimal, precision: 10, scale: 6)
      add(:tokens_used, :integer)
      add(:processing_time_ms, :integer)
      timestamps()
    end

    create(unique_index(:tier_2_quick_scans, [:article_id]))
  end
end
