defmodule Pipeline.Repo.Migrations.CreateWorkflowCosts do
  use Ecto.Migration

  def change do
    create table(:workflow_costs) do
      add(:article_id, references(:articles, on_delete: :delete_all), null: false)
      add(:total_cost, :decimal, precision: 10, scale: 6)
      add(:tier_1_cost, :decimal, precision: 10, scale: 6, default: 0)
      add(:tier_2_cost, :decimal, precision: 10, scale: 6, default: 0)
      add(:tier_2_5_cost, :decimal, precision: 10, scale: 6, default: 0)
      add(:tier_3_cost, :decimal, precision: 10, scale: 6, default: 0)
      add(:total_tokens, :integer, default: 0)
      add(:completed_at, :utc_datetime)
      timestamps()
    end

    create(unique_index(:workflow_costs, [:article_id]))
  end
end
