defmodule Torr.Torrent do
  require Logger
  import Ecto.Query
  use Torr.Web, :model

  alias Torr.Torrent

  schema "torrents" do
    field :name, :string, default: ""
    belongs_to :tracker, Tracker
    field :torrent_id, :string, default: ""
    field :json, :map, default: %{}

    timestamps()
  end

  def request(params) do
    Torrent
#            |> Map.from_struct
            |> search(params)
            |> Torr.Repo.paginate(params)
  end

#  def search(query, nil) do from p in query end
#  def search(query, "") do from p in query end
#  def search(query, %{}) do from p in query end
  def search(query, searchParams) do
    searchTerm = searchParams["search"]
    searchTerm = if searchTerm do String.replace(searchTerm,~r/\s/u, "%") end

    query
          |> where([t], fragment("? ILIKE ?", t.name, ^("%#{searchTerm}%")))
          |> order_by([t], t.inserted_at)
          |> limit(^searchParams["limit"])
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
        {:error, changeset} -> {:error, changeset}
      end
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
