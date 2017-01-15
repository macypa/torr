defmodule Torr.Repo.Migrations.CreateTracker do
  use Ecto.Migration

  def change do
    create table(:trackers) do
      add :url, :string
      add :name, :string
      add :lastPageNumber, :integer
      add :pagesAtOnce, :integer
      add :delayOnFail, :integer
      add :pagePattern, :string
      add :urlPattern, :string
      add :namePattern, :string
      add :htmlPattern, :string
      add :cookie, :text
      add :patterns, :map

      timestamps()
    end

    create unique_index(:trackers, [:url])
  end
end
