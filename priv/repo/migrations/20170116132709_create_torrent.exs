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

    create index(:torrents, [:tracker_id])
    create index(:torrents, [:torrent_id])
    create index(:torrents, [:name])
#    create index(:torrents, [:json])
    execute("CREATE INDEX json_type_index ON torrents USING GIN ((json -> 'Type'))")
    execute("CREATE INDEX json_genre_index ON torrents USING GIN ((json -> 'Genre'))")

    create unique_index(:torrents, [:tracker_id, :torrent_id])
  end
end
