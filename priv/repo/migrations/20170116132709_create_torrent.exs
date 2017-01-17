defmodule Torr.Repo.Migrations.CreateTorrent do
  use Ecto.Migration

  def change do
    create table(:torrents) do
      add :name, :string
      add :tracker_id, references(:trackers)
      add :torrent_id, :string
      add :json, :map

      timestamps()
    end

    create unique_index(:torrents, [:tracker_id, :torrent_id])
  end
end
