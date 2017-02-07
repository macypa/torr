defmodule Torr.Torrent do
  require Logger
  import Ecto.Query
  use Torr.Web, :model

  alias Torr.Torrent

  schema "torrents" do
    field :name, :string, default: ""
    field :type, :string, default: ""
    field :genre, :string, default: ""
    belongs_to :tracker, Torr.Tracker
    field :torrent_id, :string, default: ""
    field :json, :map, default: %{}

    timestamps()
  end

  def request(params) do
    torrents = Torrent
#            |> Map.from_struct
            |> search(params)
            |> filter(params)
            |> sort(params)
            |> catalogMode(params)
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

                          case order do
                             "asc" -> case field do
                                       "name" -> acc |> order_by([t], [asc: :name])
                                       "type" -> acc |> order_by([t], [asc: :type])
                                       "genre" -> acc |> order_by([t], [asc: :genre])
                                       "added" -> acc |> order_by([t], fragment("json->>'Added' asc"))
                                       "size" -> acc |> order_by([t], fragment("json->>'Size' asc"))
                                        _ -> acc
                                     end
                             "desc" -> case field do
                                        "name" -> acc |> order_by([t], [desc: :name])
                                        "type" -> acc |> order_by([t], [desc: :type])
                                        "genre" -> acc |> order_by([t], [desc: :genre])
                                        "added" -> acc |> order_by([t], fragment("json->>'Added' desc"))
                                        "size" -> acc |> order_by([t], fragment("json->>'Size' desc"))
                                        _ -> acc
                                      end
                             _ -> acc
                          end
                      end)
    else
      query |> order_by([t], [desc: :inserted_at])
    end
  end

  def catalogMode(query, searchParams) do
    sortTerm = searchParams["catalogMode"]
    unless is_nil(sortTerm) or sortTerm == "" do
       query
              |> join(:inner, [t], f in fragment("SELECT distinct on(f.json->>'uniqName') f.id, f.json->>'uniqName'  FROM torrents AS f
                                                   GROUP BY f.json->>'uniqName', f.id ORDER BY f.json->>'uniqName'"), id: t.id)
    else
      query
    end
  end

  def search(query, searchParams) do
    searchTerm = searchParams["search"]
    unless is_nil(searchTerm) or searchTerm == "" do
      searchTerm = Regex.scan(~r/"(?:\.|[^\"])*"|\S+/,searchTerm)
                   |> Enum.reduce([], fn(x, list) -> list ++ [x |> Enum.at(0)
                                                       |> String.replace_leading("\"", "")
                                                       |> String.replace_trailing("\"", "")] end)

      query = searchTerm |> Enum.reduce(query, fn x, acc ->
                          acc |> where([t], fragment("? ILIKE ?", t.name, ^("%#{x}%")))
                      end)

      searchDesc = searchParams["searchDescription"]
      unless is_nil(searchDesc) or searchDesc == "" do
        searchTerm |> Enum.reduce(query, fn x, acc ->
                                acc |> where([t], fragment("json->>'Description' ILIKE ?", ^("%#{x}%")))
                            end)
      else
        query
      end
    else
      query
    end
  end

  def filter(query, params) do
    query |> filterByTracker(params)
          |> filterByType(params)
          |> filterByGenre(params)
  end

  def filterByTracker(query, params) do
    trackers = params["tracker"]
    type = params["type"]
    genre = params["genre"]
    if is_nil(type) or type == "" or is_nil(genre) or genre == "" do
      unless is_nil(trackers) or trackers == "" do
        trackers |> String.split(",")
                 |> Enum.reduce(query, fn x, acc ->
                        acc |> or_where([c], c.tracker_id == ^x)
                    end)
      else
        query
      end
    else
      query
    end
  end

  def filterByType(query, params) do
    trackers = params["tracker"]
    type = params["type"]
    unless is_nil(type) or type == "" do
      type |> String.split(",")
           |> Enum.reduce(query, fn genr, acc ->
                unless is_nil(trackers) or trackers == "" do
                  genr = genr |> String.split(":")
                  acc = trackers |> String.split(",")
                                |> Enum.reduce(query, fn track, acc ->
                                  {intTrack, _} = Integer.parse(track)
                                  acc |> or_where([t], fragment("? ILIKE ? and ? = ? ",
                                                                t.type, ^("%#{genr}%"),
                                                                t.tracker_id, ^intTrack))
                                end)
                else
                  acc |> or_where([t], fragment("? ILIKE ?", t.type, ^("%#{genr}%")))
                end
              end)
    else
      query
    end
  end

  def filterByGenre(query, params) do
    trackers = params["tracker"]
    genre = params["genre"]
    unless is_nil(genre) or genre == "" do
      genre  |> String.split(",")
             |> Enum.reduce(query, fn genr, acc ->
                    unless is_nil(trackers) or trackers == "" do
                      genr = genr |> String.split(":")
                      acc = trackers |> String.split(",")
                                    |> Enum.reduce(query, fn track, acc ->
                                      {intTrack, _} = Integer.parse(track)
                                      acc |> or_where([t], fragment("? ILIKE ? and ? ILIKE ? and ? = ? ",
                                                                    t.type, ^("%#{genr |> Enum.at(0)}%"),
                                                                    t.genre, ^("%#{genr |> Enum.at(1)}%"),
                                                                    t.tracker_id, ^intTrack))
                                    end)
                    else
                      genr = genr |> String.split(":")
                      acc |> or_where([t], fragment("? ILIKE ? and ? ILIKE ? ", t.type, ^("%#{genr |> Enum.at(0)}%"), t.genre, ^("%#{genr |> Enum.at(1)}%")))
                    end
                end)
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
        {:ok, struct}  ->
                          Torr.FilterData.updateFilterType(struct.json["Type"])
                          Torr.FilterData.updateFilterGenre(struct.json["Type"], struct.json["Genre"])
                          {:ok, struct}
        {:error, changeset} -> {:error, changeset}
      end
  end

  def typeGenres do
    query = Torr.Torrent

    from t in query,
      distinct: true,
      select: %{type: t.type, genre: t.genre}
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:name, :genre, :type, :tracker_id, :torrent_id, :json])
    |> unique_constraint(:torrent_id)
    |> foreign_key_constraint(:tracker_id)
    |> validate_required([:tracker_id, :torrent_id])
  end
end
