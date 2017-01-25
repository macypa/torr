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
                        Torr.FilterData.updateFilterData("trackers", "#{tracker.id}:#{tracker.name}")
                  end)

    Torr.Torrent.typeGenres |> Torr.Repo.all
                             |> Enum.each(fn(key) ->
                                    type = key[:type]
                                    type_genre = if is_nil(type) or type == [] or not String.contains?(type, "/") do
                                              type
                                            else
                                              type |> String.trim |> String.split("/") |> Enum.at(0)
                                            end

                                    subType = if is_nil(type) or type == [] or not String.contains?(type, "/") do
                                              nil
                                            else
                                              type
                                            end

                                    Torr.FilterData.updateFilterData("Type", type_genre)
                                    Torr.FilterData.updateFilterData(type_genre, key[:genre])
                                    Torr.FilterData.updateFilterData(type_genre, subType)
                              end)

    Logger.info "Update filter data done"
  end

  def handle_info(:work, state) do
    doWork()
    {:noreply, state}
  end

end