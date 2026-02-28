defmodule Pipeline.Repo.Migrations.CreateTier3DeepAnalyses do
  use Ecto.Migration

  def change do
    create table(:tier_3_deep_analyses) do
      add(:article_id, references(:articles, on_delete: :delete_all), null: false)
      add(:executive_summary, :text)
      add(:extracted_frameworks, :text)
      add(:critical_assessment, :text)
      add(:extract_items, {:array, :text})
      add(:discard_items, {:array, :text})
      add(:reframe_items, :jsonb)
      add(:practical_guidance, :text)
      add(:final_assessment, :text)
      add(:api_cost, :decimal, precision: 10, scale: 6)
      add(:tokens_used, :integer)
      add(:processing_time_ms, :integer)
      timestamps()
    end

    create(unique_index(:tier_3_deep_analyses, [:article_id]))
  end
end
