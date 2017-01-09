defmodule Torr.Torrent do
  use Torr.Web, :model
  import Ecto.Query

  schema "torrents" do
    field :name, :string
    field :url, :string
    field :html, :string
    field :json, :map

    timestamps()
  end

  def search(query, searchTerm) do
    from p in query,
    where: fragment("? ILIKE ?", "name", ^searchTerm) or
            fragment("? ILIKE ?", "html", ^searchTerm)
  end

  def sorted(query) do
    from p in query,
    order_by: [desc: p.name]
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:name, :url, :html, :json])
    |> validate_required([:name, :url, :html])
  end
end
