defmodule Torr.TorrentChannel do
  require Logger
  use Phoenix.Channel

#  def join("torrent:list" <> _private_room_id, _message, socket) do
#    {:ok, socket}
#  end
  def join("torrent:" <> _private_room_id, _params, socket) do
    {:ok, socket}
  end

  def handle_in("new_msg", %{"body" => body}, socket) do
    Logger.debug "handle_in body: #{inspect(body)}"
    Logger.debug "handle_in socket: #{inspect(socket)}"

    torrents = Torr.Repo.all(Torr.Torrent)
    Logger.debug "torrent: #{inspect(torrents)}"

    broadcast! socket, "new_msg", %{body: body, torrents: to_map(torrents)}
    {:noreply, socket}
  end

  #intercept ["new_msg"]
#
#  def handle_out("new_msg", payload, socket) do
#    Logger.debug "handle_out payload: #{inspect(payload)}"
#    payload |> Map.put("html", "hjk")
#    push socket, "new_msg", payload
#    {:noreply, socket}
#  end

    defp to_map(torr) do
      %{
        "name" => torr.name,
        "html" => torr.http
      }
    end

end
