defmodule Torr.Repo.Migrations.CreateTorrent do
  use Ecto.Migration

  def change do
    create table(:torrents) do
      add :name, :string
      add :url, :string
      add :html, :text
      add :json, :map

      timestamps()
    end

  end
end
