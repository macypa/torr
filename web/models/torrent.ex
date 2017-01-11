defmodule Torr.Torrent do
  require Logger
  use Torr.Web, :model
  import Ecto.Query

  schema "torrents" do
    field :name, :string
    field :url, :string, unique: true
    field :html, :string
    field :json, :map

    timestamps()
  end

  def search(query, searchTerm) do
    searchTerm = searchTerm |> String.replace(~r/\s/u, "%")
    from p in query,
    where: fragment("? ILIKE ?", p.name, ^("%#{searchTerm}%")) or
            fragment("? ILIKE ?", p.html, ^("%#{searchTerm}%"))
  end

  def sorted(query) do
    from p in query,
    order_by: [desc: p.name]
  end

  def save(torrentMap) do
      result =
        case Torr.Repo.get_by(Torr.Torrent, url: torrentMap.url) do
          nil  -> %Torr.Torrent{url: torrentMap.url} # Post not found, we build one
          torrent -> torrent          # Post exists, let's use it
        end
        |> Torr.Torrent.changeset(torrentMap)
        |> Torr.Repo.insert_or_update

      case result do
        {:ok, _struct}  -> {:ok, _struct}  #Logger.debug "torrent: #{inspect(struct)}"# Inserted or updated with success
        {:error, changeset} ->
          Logger.debug "can't save torrent with changeset: #{inspect(changeset)}"# Something went wrong
          {:error, changeset}
      end
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:name, :url, :html, :json])
    |> unique_constraint(:url)
    |> validate_required([:name, :url, :html])
  end
end
