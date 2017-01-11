defmodule Torr.Torrent do
  require Logger
  use Torr.Web, :model
  import Ecto.Query

  schema "torrents" do
    field :name, :string, default: ""
    field :url, :string, unique: true
    field :html, :string, default: ""
    field :json, :map, default: %{}

    timestamps()
  end

#  def search(query, nil) do from p in query end
#  def search(query, "") do from p in query end
#  def search(query, %{}) do from p in query end
  def search(query, searchParams) do
    Logger.debug "search searchParams: #{inspect(searchParams)}"
    searchTerm = searchParams["search"] |> String.replace(~r/\s/u, "%")
    from p in query,
    where: fragment("? ILIKE ?", p.name, ^("%#{searchTerm}%")) or
            fragment("? ILIKE ?", p.html, ^("%#{searchTerm}%"))
  end

  def allUrlWithEmptyName(query, trackerUrl) do
    from p in query,
#    select: {p.name, p.url},
    where: fragment("? ILIKE ?", p.url, ^("%#{trackerUrl}%")) and
            fragment("? = ?", p.name, ^(""))
  end

  def sorted(query) do
    from p in query,
    order_by: [desc: p.name]
  end

  def save(torrentMap) do
      result =
        case Torr.Repo.get_by(Torr.Torrent, url: torrentMap.url) do
          nil  -> %Torr.Torrent{url: torrentMap.url}
          torrent -> torrent
        end
        |> Torr.Torrent.changeset(torrentMap)
        |> Torr.Repo.insert_or_update

      case result do
        {:ok, struct}  -> {:ok, struct}
        {:error, changeset} -> {:error, changeset}
      end
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:name, :url, :html, :json])
    |> unique_constraint(:url)
    |> validate_required([:url])
  end
end
