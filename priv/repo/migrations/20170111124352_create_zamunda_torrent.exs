defmodule Torr.Repo.Migrations.CreateZamundaTorrent do
  use Ecto.Migration

  def change do
    create table(:zamunda_torrents) do
      add :name, :string
      add :tracker_id, references(:trackers)
      add :torrent_id, :string
      add :page, :integer
      add :content_html, :text

      timestamps()
    end

    create unique_index(:zamunda_torrents, [:tracker_id, :torrent_id])
  end
end
