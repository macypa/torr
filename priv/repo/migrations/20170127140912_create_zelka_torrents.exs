defmodule Torr.Repo.Migrations.CreateZelkaTorrent do
  use Ecto.Migration

  def change do
    create table(:zelka_torrents) do
      add :name, :string
      add :tracker_id, references(:trackers)
      add :torrent_id, :string
      add :page, :integer
      add :content_html, :text

      timestamps()
    end

    create index(:zelka_torrents, [:tracker_id])
    create index(:zelka_torrents, [:torrent_id])
    create unique_index(:zelka_torrents, [:tracker_id, :torrent_id])
  end
end
