defmodule Torr.UpdateFilter do
  require Logger
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, %{})
  end

  def init(state) do
    Process.send_after(self(), :work, 1)
    {:ok, state}
  end

  def doWork() do

    Torr.Tracker |> Torr.Repo.all
                 |> Enum.each(fn(tracker) ->
                        Torr.FilterData.updateFilterData("trackers", "#{tracker.name}")
                  end)

    typesGenres = Torr.Torrent.typeGenres |> Torr.Repo.all



    filterDataType = case Torr.Repo.get_by(Torr.FilterData, key: "Type") do
                    nil  -> %Torr.FilterData{key: "Type"}
                    filterData -> filterData
                  end
    filterDataGenre = case Torr.Repo.get_by(Torr.FilterData, key: "Genre") do
                    nil  -> %Torr.FilterData{key: "Genre"}
                    filterData -> filterData
                  end


    typesGenres |> Enum.reduce(filterDataType, fn x, acc ->
                                      Torr.FilterData.updateFilterType(acc, x[:type])
                                    end)
                |> Map.from_struct
                |> Torr.FilterData.save

    typesGenres |> Enum.reduce(filterDataGenre, fn x, acc ->
                                      Torr.FilterData.updateFilterGenre(acc, x[:type], x[:genre])
                                    end)
                |> Map.from_struct
                |> Torr.FilterData.save

    Logger.info "Update filter data done"
  end

  def handle_info(:work, state) do
    doWork()
    {:noreply, state}
  end

end