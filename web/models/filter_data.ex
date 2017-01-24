defmodule Torr.FilterData do
  use Torr.Web, :model

  schema "filter_data" do
    field :key, :string, unique: true
    field :value, :string

    timestamps()
  end

  def updateFilterData(key, values) do
    filterData = case Torr.Repo.get_by(Torr.FilterData, key: key) do
      nil  -> %Torr.FilterData{key: key}
      filterData -> filterData
    end

    filterData = Map.put(filterData, :value, "#{filterData.value} #{values |> String.replace(",", "")}")
    save(filterData)
  end

  def save(filterMap) do
      result =
        case Torr.Repo.get_by(Torr.FilterData, key: filterMap.key) do
          nil  -> %Torr.FilterData{key: filterMap.key}
          filterData -> filterData
        end
        |> Torr.FilterData.changeset(filterMap)
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
    |> cast(params, [:key, :value])
    |> validate_required([:key, :value])
    |> unique_constraint(:url)
  end
end
