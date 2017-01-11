defmodule Torr.Repo.Migrations.CreateTracker do
  use Ecto.Migration

  def change do
    create table(:trackers) do
      add :url, :string
      add :name, :string
      add :lastPageNumber, :integer
      add :pagePattern, :string
      add :urlPattern, :string
      add :namePattern, :string
      add :htmlPattern, :string
      add :cookie, :text

      timestamps()
    end

    create unique_index(:torrents, [:url])
  end
end
