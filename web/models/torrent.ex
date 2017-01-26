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
            |> sort(params)
            |> with_tracker()
            |> Torr.Repo.paginate(params)

#    Logger.info "torrents : #{inspect(torrents)}"
    torrents
  end

  def sort(query, searchParams) do
    sortTerm = searchParams["sort"]
    unless is_nil(sortTerm) or sortTerm == "" do
        sortTerm |> String.split(",")
                  |> Enum.reduce(query, fn x, acc ->
                          field = x |> String.replace(~r/_.*/, "")
                          order = x |> String.replace(~r/.*_/, "")

                          case field do
                            "" -> case order do
                                    "asc" -> acc |> order_by([t], [asc: :name])
                                    "desc" -> acc |> order_by([t], [desc: :name])
                                  end
                            field -> case order do
                                       "asc" -> case field do
                                                 "type" -> acc |> order_by([t], fragment("json->>'Type' asc"))
                                                 "genre" -> acc |> order_by([t], fragment("json->>'Genre' asc"))
                                                 "added" -> acc |> order_by([t], fragment("json->>'Added' asc"))
                                                 "size" -> acc |> order_by([t], fragment("json->>'Size' asc"))
                                               end
                                       "desc" -> case field do
                                                  "type" -> acc |> order_by([t], fragment("json->>'Type' desc"))
                                                  "genre" -> acc |> order_by([t], fragment("json->>'Genre' desc"))
                                                  "added" -> acc |> order_by([t], fragment("json->>'Added' desc"))
                                                  "size" -> acc |> order_by([t], fragment("json->>'Size' desc"))
                                                end
                                     end
                          end
                      end)
    else
      query |> order_by([t], [desc: :inserted_at])
    end
  end

  def search(query, searchParams) do
    searchTerm = searchParams["search"]
    if searchTerm do
      String.replace(searchTerm,~r/\s/u, "%")
      query
            |> where([t], fragment("? ILIKE ?", t.name, ^("%#{searchTerm}%")))
#          |> where([t], fragment("(json#>>'{Description}') ILIKE ?", ^("%#{searchTerm}%")))
    else
      query
    end
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
