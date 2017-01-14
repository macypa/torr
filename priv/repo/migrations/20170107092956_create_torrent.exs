defmodule Torr.Repo.Migrations.CreateTorrent do
  use Ecto.Migration

  def change do
    create table(:torrents) do
      add :name, :string
      add :url, :string
      add :pageUrl, :string
      add :html, :text
      add :json, :map

      timestamps()
    end

    create unique_index(:torrents, [:url])
  end
end
