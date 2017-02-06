defmodule Torr.Repo.Migrations.AddTypeGenreToTorrent do
  use Ecto.Migration

  def change do
    alter table(:torrents) do
      add :type, :string, default: ""
      add :genre, :string, default: ""
    end

    create index(:torrents, [:type])
    create index(:torrents, [:genre])
  end
end
