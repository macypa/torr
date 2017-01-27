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

    filterData = updateFilterData(filterData, key, values)
    save(filterData |> Map.from_struct)
  end

  def updateFilterData(filterData, key, values) do
    unless is_nil(key) or key |> String.trim == "" or is_nil(values) or values |> String.trim == "" do
      new_values = if is_nil(filterData.value) or filterData.value |> String.trim == "" do
                      values
                    else
                      filterData.value <> ", " <> values
                    end

      values = new_values |> String.replace("\s+", " ")
                      |> String.split(", ")
                      |> Enum.uniq
                      |> Enum.sort
                      |> Enum.join(", ")
                      |> String.trim

      values = values |> String.replace(~r/^, /, "")
      unless values == ", " or values == "" or values == filterData.value do
        Map.put(filterData, :value, values)
      else
        filterData
      end
    else
      filterData
    end
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

  def to_map(data) do
    Enum.reduce data, %{}, fn data, acc ->
      Map.put(acc, data.key, data.value)
    end
  end
end
