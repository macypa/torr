defmodule Torr.Tracker do
  require Logger
  use Torr.Web, :model

  schema "trackers" do
    field :url, :string, unique: true
    field :name, :string, default: ""
    field :lastPageNumber, :integer, default: -1
    field :pagesAtOnce, :integer, default: 1
    field :delayOnFail, :integer, default: 1000
    field :pagePattern, :string, default: ""
    field :infoUrl, :string, default: ""
    field :urlPattern, :string, default: ""
    field :namePattern, :string, default: ""
    field :htmlPattern, :string, default: ""
    field :cookie, :string, default: ""
    field :patterns, :map, default: %{}

    timestamps()
  end

  def save(trackerMap) do
      result =
        case Torr.Repo.get_by(Torr.Tracker, url: trackerMap.url) do
          nil  -> %Torr.Tracker{url: trackerMap.url}
          tracker -> tracker
        end
        |> Torr.Tracker.changeset(trackerMap)
        |> Torr.Repo.insert_or_update

      case result do
        {:ok, struct}  -> {:ok, struct}
        {:error, changeset} -> {:error, changeset}
      end
  end

  def getQuery(tracker) do
      case tracker.name do
        "zamunda.net" -> Torr.ZamundaTorrent.query
        "zelka.org" -> Torr.ZelkaTorrent.query
        _ -> throw :break
      end
  end

  def getKind(tracker) do
      case tracker.name do
        "zamunda.net" -> Torr.ZamundaTorrent
        "zelka.org" -> Torr.ZelkaTorrent
        _ -> throw :break
      end
  end

  def to_struct(kind, attrs) do
    struct = struct(kind)
    Enum.reduce Map.to_list(struct), struct, fn {k, _}, acc ->
      case Map.fetch(attrs, Atom.to_string(k)) do
        {:ok, v} -> %{acc | k => v}
        :error -> acc
      end
    end
  end

  def saveTorrent(tracker, torrentMap) do
      kind = getKind(tracker)
      result =
        case Torr.Repo.get_by(getQuery(tracker), torrent_id: torrentMap.torrent_id) do
          nil  -> to_struct(kind, %{torrent_id: torrentMap.torrent_id})
          torrent -> torrent
        end
        |> kind.changeset(torrentMap)
        |> Torr.Repo.insert_or_update

      case result do
        {:ok, struct}  -> {:ok, struct}
        {:error, changeset} -> {:error, changeset}
      end
  end

  def allWithEmptyName(tracker) do
    getQuery(tracker) |> where([t], t.name == ^"")
  end

  def notProcessed(tracker) do
    query = getQuery(tracker)

#    torrSubQuery = from torr in Torr.Torrent, select: torr.torrent_id

    from z in query,
      where: fragment(" NOT EXISTS (SELECT * FROM torrents AS t  WHERE ? = t.torrent_id and ? = t.tracker_id )", z.torrent_id, ^tracker.id),
      select: z.id,
      order_by: [z.id]
  end

#  def saveTorrent(torrentMap) do
#      Logger.info "tracker.saveTorrent self: #{inspect(self())}"
#
#      case self().url do
#        url ->
#            Logger.info "tracker.saveTorrent zamunda: #{inspect(url)}"
#            Torr.ZamundaTorrent.save(self().id, torrentMap)
#      end
#  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:url, :name, :lastPageNumber, :infoUrl, :pagePattern, :urlPattern, :namePattern, :htmlPattern, :cookie, :patterns, :pagesAtOnce])
    |> validate_required([:url, :name, :lastPageNumber, :infoUrl, :pagePattern, :urlPattern, :namePattern, :htmlPattern, :cookie, :patterns, :pagesAtOnce])
    |> unique_constraint(:url)
  end
end
