defmodule Torr.Repo.Migrations.AddInfoUrlToTracker do
  use Ecto.Migration

  def change do
    alter table(:trackers) do
      add :infoUrl, :string, default: ""
    end
  end
end
