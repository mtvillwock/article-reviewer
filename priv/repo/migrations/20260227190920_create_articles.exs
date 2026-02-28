defmodule Pipeline.Repo.Migrations.CreateArticles do
  use Ecto.Migration

  def change do
    create table(:articles) do
      add(:url, :text, null: false)
      add(:title, :text)
      add(:content, :text)
      add(:status, :string, default: "pending", null: false)
      add(:fetch_error, :string)
      add(:fetch_error_details, :text)
      add(:retry_count, :integer, default: 0, null: false)
      add(:last_fetch_attempt, :utc_datetime)
      add(:fetch_strategy, :string)
      timestamps()
    end

    create(unique_index(:articles, [:url]))
    create(index(:articles, [:status]))
  end
end
