defmodule Torr.ZamundaTorrent do
  require Logger
  use Torr.Web, :model

  schema "zamunda_torrents" do
    field :name, :string, default: ""
    belongs_to :tracker, Torr.Tracker
    field :torrent_id, :string, default: ""
    field :page, :integer, default: 1
    field :content_html, :string, default: ""

    timestamps()
  end

  def save(torrentMap) do
      result =
        case Torr.Repo.get_by(Torr.ZamundaTorrent, torrent_id: torrentMap.torrent_id) do
          nil  -> %Torr.ZamundaTorrent{torrent_id: torrentMap.torrent_id}
          torrent -> torrent
        end
        |> Torr.ZamundaTorrent.changeset(torrentMap)
        |> Torr.Repo.insert_or_update

      case result do
        {:ok, struct}  -> {:ok, struct}
        {:error, changeset} -> {:error, changeset}
      end
  end

  def allWithEmptyName() do
    Torr.ZamundaTorrent |> where([t], t.name == ^"")
  end

  def notProcessed(tracker) do
    query = Torr.ZamundaTorrent

#    torrSubQuery = from torr in Torr.Torrent, select: torr.torrent_id

    from z in query,
      where: fragment(" NOT EXISTS (SELECT * FROM torrents AS t  WHERE ? = t.torrent_id and ? = t.tracker_id )", z.torrent_id, ^tracker.id),
      select: z.id,
      order_by: [z.id]
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:name, :tracker_id, :torrent_id, :page, :content_html])
    |> unique_constraint(:torrent_id)
    |> foreign_key_constraint(:tracker_id)
    |> validate_required([:torrent_id, :page])
  end
end
