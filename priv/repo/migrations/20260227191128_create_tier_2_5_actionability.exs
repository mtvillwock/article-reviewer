defmodule Pipeline.Repo.Migrations.CreateTier25Actionability do
  use Ecto.Migration

  def change do
    create table(:tier_2_5_actionability) do
      add(:article_id, references(:articles, on_delete: :delete_all), null: false)
      add(:one_sentence_essence, :text)
      add(:quick_start_checklist, :text)
      add(:implementation_template, :text)
      add(:integration_guide, :text)
      add(:failure_modes, :text)
      add(:success_indicators, :text)
      add(:iteration_triggers, :text)
      add(:api_cost, :decimal, precision: 10, scale: 6)
      add(:tokens_used, :integer)
      add(:processing_time_ms, :integer)
      timestamps()
    end

    create(unique_index(:tier_2_5_actionability, [:article_id]))
  end
end
