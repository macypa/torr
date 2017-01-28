defmodule Torr.ArenaTorrent do
  use Torr.Web, :model

  schema "arena_torrents" do
    field :name, :string, default: ""
    belongs_to :tracker, Torr.Tracker
    field :torrent_id, :string, default: ""
    field :page, :integer, default: 1
    field :content_html, :string, default: ""

    timestamps()
  end

  def query() do
      from k in Torr.ArenaTorrent
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
    |> validate_length(:torrent_id, min: 1)
  end
end
