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

  def allWithEmptyName() do
      case self().url do
        _ -> Torr.ZamundaTorrent.allWithEmptyName()
      end
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
