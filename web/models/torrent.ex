defmodule Torr.Torrent do
  require Logger
  import Ecto.Query
  use Torr.Web, :model

  alias Torr.Torrent

  schema "torrents" do
    field :name, :string, default: ""
    field :type, :string, default: ""
    field :genre, :string, default: ""
    field :uniq_name, :string, default: ""
    belongs_to :tracker, Torr.Tracker
    field :torrent_id, :string, default: ""
    field :json, :map, default: %{}

    timestamps()
  end

  def request(params) do
    torrents = Torrent
#            |> Map.from_struct
            |> search(params)
#            |> filter(params)
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
    dynamic = unless is_nil(searchTerm) or searchTerm == "" do
      searchTerm = Regex.scan(~r/"(?:\.|[^\"])*"|\S+/,searchTerm)
                   |> Enum.reduce([], fn(x, list) -> list ++ [x |> Enum.at(0)
                                                       |> String.replace_leading("\"", "")
                                                       |> String.replace_trailing("\"", "")] end)

      dynamic = searchTerm |> Enum.reduce(nil, fn x, acc ->
                            if String.starts_with?(x, "-") do
                              x = String.slice(x, 1..-1)
                              case acc do
                                nil -> dynamic([t], fragment("? NOT ILIKE ?", t.name, ^("%#{x}%")))
                                acc -> dynamic([t], fragment("? NOT ILIKE ?", t.name, ^("%#{x}%")) and ^acc)
                              end
                            else
                              case acc do
                                nil -> dynamic([t], fragment("? ILIKE ?", t.name, ^("%#{x}%")))
                                acc -> dynamic([t], fragment("? ILIKE ?", t.name, ^("%#{x}%")) and ^acc)
                              end
                            end
                      end)

      searchDesc = searchParams["searchDescription"]
      unless is_nil(searchDesc) or searchDesc == "" do
                    searchTerm |> Enum.reduce(dynamic, fn x, acc ->
                                      if String.starts_with?(x, "-") do
                                        x = String.slice(x, 1..-1)
                                        case acc do
                                          nil -> dynamic([t], fragment("json->>'Description' NOT ILIKE ?", ^("%#{x}%")))
                                          acc -> dynamic([t], fragment("json->>'Description' NOT ILIKE ?", ^("%#{x}%")) and ^acc)
                                        end
                                      else
                                        case acc do
                                          nil -> dynamic([t], fragment("json->>'Description' ILIKE ?", ^("%#{x}%")))
                                          acc -> dynamic([t], fragment("json->>'Description' ILIKE ?", ^("%#{x}%")) and ^acc)
                                        end
                                      end
                                end)
                else
                    dynamic
                end
    end

    dynamic = filter(dynamic, searchParams)
    case dynamic do
      nil -> query
      dynamic -> from query, where: ^dynamic
    end

  end

  def filter(dynamic, params) do
    dynamic |> filterByTracker(params)
            |> filterByType(params)
            |> filterByGenre(params)
  end

  def filterByTracker(dynamic, params) do
    trackers = params["tracker"]
    unless is_nil(trackers) or trackers == "" do
      dynamicToAdd = trackers |> String.split(",")
               |> Enum.reduce(nil, fn x, acc ->
                      case acc do
                        nil -> dynamic([c], c.tracker_id == ^x)
                        acc -> dynamic([c], c.tracker_id == ^x or ^acc)
                      end
                  end)
      case dynamic do
        nil -> dynamicToAdd
        dynamic -> dynamic([d], ^dynamicToAdd and ^dynamic)
      end
    else
      dynamic
    end
  end

  def filterByType(dynamic, params) do
    type = params["type"]
    unless is_nil(type) or type == "" do
      dynamicToAdd = type |> String.split(",")
                         |> Enum.reduce(nil, fn x, acc ->
                                case acc do
                                  nil -> dynamic([t], fragment("? ILIKE ?", t.type, ^("%#{x}%")))
                                  acc -> dynamic([t], fragment("? ILIKE ?", t.type, ^("%#{x}%")) or ^acc)
                                end
                            end)
      case dynamic do
        nil -> dynamicToAdd
        dynamic -> dynamic([d], ^dynamicToAdd and ^dynamic)
      end
    else
      dynamic
    end
  end

  def filterByGenre(dynamic, params) do
    genre = params["genre"]
    unless is_nil(genre) or genre == "" do
      dynamicToAdd = genre  |> String.split(",")
             |> Enum.reduce(nil, fn genre, acc ->
                        type = genre |> String.split(":") |> Enum.at(0)
                        genr = genre |> String.split(":") |> Enum.at(1)
                        if String.starts_with?(genr, "-") do
                          genr = String.slice(genr, 1..-1)
                          case acc do
                            nil -> dynamic([t], fragment("? ILIKE ? and ? NOT ILIKE ? ", t.type, ^("%#{type}%"), t.genre, ^("%#{genr}%")))
                            acc -> dynamic([t], fragment("? ILIKE ? and ? NOT ILIKE ? ", t.type, ^("%#{type}%"), t.genre, ^("%#{genr}%")) or ^acc)
                          end
                        else
                          case acc do
                            nil -> dynamic([t], fragment("? ILIKE ? and ? ILIKE ? ", t.type, ^("%#{type}%"), t.genre, ^("%#{genr}%")))
                            acc -> dynamic([t], fragment("? ILIKE ? and ? ILIKE ? ", t.type, ^("%#{type}%"), t.genre, ^("%#{genr}%")) or ^acc)
                          end
                        end
                end)
      case dynamic do
        nil -> dynamicToAdd
        dynamic -> dynamic([d], ^dynamicToAdd and ^dynamic)
      end
    else
      dynamic
    end
  end

  def with_tracker(query) do
    from q in query, preload: :tracker
  end

  def sorted(query) do
    from p in query,
    order_by: [desc: p.name]
  end

  def get_by(torrentMap) do
    case Torr.Repo.get_by(Torr.Torrent, [tracker_id: torrentMap.tracker_id, torrent_id: torrentMap.torrent_id]) do
      nil  ->  %Torr.Torrent{tracker_id: torrentMap.tracker_id, torrent_id: torrentMap.torrent_id}
      torrent -> torrent
    end
  end

  def save(torrentMap) do
      result = Torr.Torrent.get_by(torrentMap)
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

  def allWithEmptyType(query) do
    from t in query,
      where: t.type == ^"",
      select: %{tracker_id: t.tracker_id, torrent_id: t.torrent_id}
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
    |> cast(params, [:name, :uniq_name, :genre, :type, :tracker_id, :torrent_id, :json])
    |> unique_constraint(:torrent_id)
    |> foreign_key_constraint(:tracker_id)
    |> validate_required([:tracker_id, :torrent_id])
  end
end
