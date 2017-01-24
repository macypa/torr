defmodule Torr.Repo.Migrations.CreateFilterData do
  use Ecto.Migration

  def change do
    create table(:filter_data) do
      add :key, :string
      add :value, :string

      timestamps()
    end

    create unique_index(:filter_data, [:key])
  end
end
