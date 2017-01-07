defmodule Torr.Torrent do
  use Torr.Web, :model

  schema "torrents" do
    field :name, :string
    field :url, :string
    field :html, :string
    field :json, :map

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:name, :url, :html, :json])
    |> validate_required([:name, :url, :html, :json])
  end
end
