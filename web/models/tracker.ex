defmodule Torr.Tracker do
  use Torr.Web, :model

  schema "trackers" do
    field :url, :string, unique: true
    field :name, :string, default: ""
    field :lastPageNumber, :integer, default: 0
    field :pagePattern, :string, default: ""
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

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:url, :name, :lastPageNumber, :pagePattern, :urlPattern, :namePattern, :htmlPattern, :cookie, :patterns])
    |> validate_required([:url, :name, :lastPageNumber, :pagePattern, :urlPattern, :namePattern, :htmlPattern, :cookie, :patterns])
    |> unique_constraint(:url)
  end
end
