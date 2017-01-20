defmodule Torr.TorrentController do
  require Logger
  use Torr.Web, :controller

  alias Torr.Torrent

  def index(conn, params) do
    Logger.debug "index params: #{inspect(params)}"

#    params = unless (Map.has_key?(params, :page)) do Map.put(params, :page, "1") end
#    params = unless (Map.has_key?(params, :page_size)) do Map.put(params, :page_size, "5") end
#    Logger.debug "index params: #{inspect(params)}"

    torrents = Torrent.request(params)
#    torrents = Torrent
#           |> Torrent.search(params)
#           |> Torr.Repo.paginate(params)

#    Logger.debug "index torrent: #{inspect(torrents)}"
    render(conn, "index.html", params: params, torrents: torrents)
  end

  def new(conn, _params) do
    changeset = Torrent.changeset(%Torrent{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"torrent" => torrent_params}) do

    torrent_params = Torr.EncodeHelper.decode(torrent_params, "json")
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
#    Logger.debug "torrent: #{inspect(torrent)}"

    render(conn, "show.html", torrent: torrent)
  end

  def edit(conn, %{"id" => id}) do
    torrent = Repo.get!(Torrent, id)
    changeset = Torrent.changeset(torrent)
    render(conn, "edit.html", torrent: torrent, changeset: changeset)
  end

  def update(conn, %{"id" => id, "torrent" => torrent_params}) do

    torrent_params = Torr.EncodeHelper.decode(torrent_params, "json")

    torrent = Repo.get!(Torrent, id)
    changeset = Torrent.changeset(torrent, torrent_params)

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

#SELECT * from torrents where (json#>>'{Genre}') ILIKE '%rock%';

end
