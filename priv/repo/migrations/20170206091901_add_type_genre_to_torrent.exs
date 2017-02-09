defmodule Torr.Repo.Migrations.AddTypeGenreToTorrent do
  use Ecto.Migration

  def change do
    alter table(:torrents) do
      add :type, :string, default: ""
      add :genre, :string, default: ""
      add :uniq_name, :string, default: ""
    end

    create index(:torrents, [:type])
    create index(:torrents, [:genre])
    create index(:torrents, [:uniq_name])
  end
end
