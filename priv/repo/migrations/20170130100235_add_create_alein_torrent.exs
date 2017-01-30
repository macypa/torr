defmodule Torr.Repo.Migrations.AddCreateAleinTorrent do
  use Ecto.Migration

  def change do
    create table(:alein_torrents) do
      add :name, :string
      add :tracker_id, references(:trackers)
      add :torrent_id, :string
      add :page, :integer
      add :content_html, :text

      timestamps()
    end

    create index(:alein_torrents, [:tracker_id])
    create index(:alein_torrents, [:torrent_id])
    create unique_index(:alein_torrents, [:tracker_id, :torrent_id])
  end
end
