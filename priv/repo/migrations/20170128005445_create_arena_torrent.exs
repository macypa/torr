defmodule Torr.Repo.Migrations.CreateArenaTorrent do
  use Ecto.Migration

  def change do
    create table(:arena_torrents) do
      add :name, :string
      add :tracker_id, references(:trackers)
      add :torrent_id, :string
      add :page, :integer
      add :content_html, :text

      timestamps()
    end

    create index(:arena_torrents, [:tracker_id])
    create index(:arena_torrents, [:torrent_id])
    create unique_index(:arena_torrents, [:tracker_id, :torrent_id])
  end
end
