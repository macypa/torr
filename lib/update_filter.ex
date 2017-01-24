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
#    torrents = Torr.Repo.all(Torr.Torrent)
#
#    for torrent <- torrents do
#      Torr.FilterData.updateFilterData("Type", torrent.json["Type"])
#      Torr.FilterData.updateFilterData("Genre", torrent.json["Genre"])
#    end
  end

  def handle_info(:work, state) do
    doWork()
    {:noreply, state}
  end

end