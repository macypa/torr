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
                                    Torr.FilterData.updateFilterData("Type", key[:type])
                                    Torr.FilterData.updateFilterData("Genre", key[:genre])
                              end)

    Logger.info "Update filter data done"
  end

  def handle_info(:work, state) do
    doWork()
    {:noreply, state}
  end

end