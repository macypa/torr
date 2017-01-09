defmodule Torr.TorrentController do
  require Logger
  use Torr.Web, :controller

  alias Torr.Torrent

  def index(conn, params) do
    Logger.debug "index params: #{inspect(params)}"
    torrents = Repo.all(Torrent)
#    Torr.TorrentChannel.broadcast_change(conn.assigns.user_id, torrents)
    render(conn, "index.html", torrents: torrents)
  end

  def new(conn, _params) do
    changeset = Torrent.changeset(%Torrent{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"torrent" => torrent_params}) do

    torrent_params = Map.drop(torrent_params, ["json"])
    |> Map.put("json", Poison.decode!(torrent_params["json"]))
    Logger.debug "create torrent_params updated: #{inspect(torrent_params)}"

    changeset = Torrent.changeset(%Torrent{}, torrent_params)

    case Repo.insert(changeset) do
      {:ok, _torrent} ->
        conn
        |> put_flash(:info, "Torrent created successfully.")
        |> redirect(to: torrent_path(conn, :index))
      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    torrent = Repo.get!(Torrent, id)
    Logger.debug "torrent: #{inspect(torrent)}" 

    render(conn, "show.html", torrent: torrent)
  end

  def edit(conn, %{"id" => id}) do
    torrent = Repo.get!(Torrent, id)
    changeset = Torrent.changeset(torrent)
    render(conn, "edit.html", torrent: torrent, changeset: changeset)
  end

  def update(conn, %{"id" => id, "torrent" => torrent_params}) do

    torrent_params = Map.drop(torrent_params, ["json"])
    |> Map.put("json", Poison.decode!(torrent_params["json"]))
    Logger.debug "torrent_params updated: #{inspect(torrent_params)}" 

    torrent = Repo.get!(Torrent, id)
    changeset = Torrent.changeset(torrent, torrent_params)
    Logger.debug "changeset: #{inspect(changeset)}" 

    case Repo.update(changeset) do
      {:ok, torrent} ->
        conn
        |> put_flash(:info, "Torrent updated successfully.")
        |> redirect(to: torrent_path(conn, :show, torrent))
      {:error, changeset} ->
        render(conn, "edit.html", torrent: torrent, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    torrent = Repo.get!(Torrent, id)

    # Here we use delete! (with a bang) because we expect
    # it to always work (and if it does not, it will raise).
    Repo.delete!(torrent)

    conn
    |> put_flash(:info, "Torrent deleted successfully.")
    |> redirect(to: torrent_path(conn, :index))
  end

#SELECT DISTINCT json->'somethingelse'->>'genres' as genres from torrents;


end

defimpl Phoenix.HTML.Safe, for: Map do
  def to_iodata(data), do: data |> Poison.encode! |> Plug.HTML.html_escape
end