defmodule Torr.Torrent do
  require Logger
  import Ecto.Query
  use Torr.Web, :model

  alias Torr.Torrent

  schema "torrents" do
    field :name, :string, default: ""
    belongs_to :tracker, Torr.Tracker
    field :torrent_id, :string, default: ""
    field :json, :map, default: %{}

    timestamps()
  end

  def request(params) do
    torrents = Torrent
#            |> Map.from_struct
            |> search(params)
            |> Torr.Repo.paginate(params)

    torrents
  end

  def search(query, searchParams) do
    searchTerm = searchParams["search"]
    searchTerm = if searchTerm do String.replace(searchTerm,~r/\s/u, "%") end

    query
          |> where([t], fragment("? ILIKE ?", t.name, ^("%#{searchTerm}%")))
          |> order_by([t], desc: t.inserted_at)
          |> limit(^searchParams["limit"])
          |> with_tracker()
  end

  def with_tracker(query) do
    from q in query, preload: :tracker
  end

  def sorted(query) do
    from p in query,
    order_by: [desc: p.name]
  end

  def save(_tracker, torrentMap) do
      result =
        case Torr.Repo.get_by(Torr.Torrent, [tracker_id: torrentMap.tracker_id, torrent_id: torrentMap.torrent_id]) do
          nil  ->  %Torr.Torrent{tracker_id: torrentMap.tracker_id, torrent_id: torrentMap.torrent_id}
          torrent -> torrent
        end
        |> Torr.Torrent.changeset(torrentMap)
        |> Torr.Repo.insert_or_update

      case result do
        {:ok, struct}  -> {:ok, struct}
                          Torr.FilterData.updateFilterData("Type", struct.json["Type"])
                          Torr.FilterData.updateFilterData(struct.json["Type"], struct.json["Genre"])
        {:error, changeset} -> {:error, changeset}
      end
  end

  def typeGenres do
    query = Torr.Torrent

    from t in query,
      distinct: true,
      select:  %{
        type: fragment("json->'Type'"),
        genre: fragment("json->'Genre'")
      }
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:name, :tracker_id, :torrent_id, :json])
    |> unique_constraint(:torrent_id)
    |> foreign_key_constraint(:tracker_id)
    |> validate_required([:tracker_id, :torrent_id])
  end
end
