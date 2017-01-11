defmodule Torr.TorrentChannel do
  require Logger
  use Phoenix.Channel

  alias Torr.Torrent
#  def join("torrent:list" <> _private_room_id, _message, socket) do
#    {:ok, socket}
#  end
  def join("torrent:" <> _private_room_id, _params, socket) do
#    case Torr.Repo.all(Torr.Torrent) do
#      nil ->  {:error, %{reason: "channel: No such torrents"}}
#      torrents ->
#        {:ok, to_map(torrents), socket}
#    end
    {:ok, socket}
  end

  def handle_in("new_msg", params, socket) do
    Logger.debug "handle_in body: #{inspect(params)}"
    Logger.debug "handle_in socket: #{inspect(socket)}"

    torrents = Torrent
               |> Torrent.search(params)
               |> Torr.Repo.all
    Logger.debug "torrent: #{inspect(torrents)}"

    torrentsHtml = Phoenix.View.render_to_string(Torr.TorrentView, "torrents.html", torrents: torrents)
    Logger.debug "handle_in torrentsHtml: #{inspect(torrentsHtml)}"
    broadcast! socket, "new_msg", %{html: torrentsHtml, torrents: to_map(torrents)}
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

#  def broadcast_change(user_id, torrents) do
#    Logger.debug "broadcast_change user_id: #{inspect(user_id)}"
##    broadcast! "torrent:" <> user_id, "new_msg", %{torrents: to_map(torrents)}
#    Torr.Endpoint.broadcast("torrent:#{user_id}", "new_msg", %{torrents: to_map(torrents)})
#  end

  def to_map(torrs) do
    torrents = Enum.reduce torrs, %{}, fn torrent, acc ->
      Map.put(acc, torrent.name, %{"name" => torrent.name, "html" => torrent.html})
    end
    Logger.debug "to_map torrents: #{inspect(torrents)}"
      torrents
  end

end
