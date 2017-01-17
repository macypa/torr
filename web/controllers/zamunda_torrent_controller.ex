defmodule Torr.ZamundaTorrentController do
  use Torr.Web, :controller

  alias Torr.ZamundaTorrent

  def index(conn, params) do
    zamunda_torrents = ZamundaTorrent
              |> order_by([t], t.inserted_at)
              |> Torr.Repo.paginate(params)
#               |> Repo.all
    render(conn, "index.html", zamunda_torrents: zamunda_torrents)
  end

  def new(conn, _params) do
    changeset = ZamundaTorrent.changeset(%ZamundaTorrent{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"zamunda_torrent" => zamunda_torrent_params}) do
    changeset = ZamundaTorrent.changeset(%ZamundaTorrent{}, zamunda_torrent_params)

    case Repo.insert(changeset) do
      {:ok, _zamunda_torrent} ->
        conn
        |> put_flash(:info, "Zamunda torrent created successfully.")
        |> redirect(to: zamunda_torrent_path(conn, :index))
      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    zamunda_torrent = Repo.get!(ZamundaTorrent, id)
    render(conn, "show.html", zamunda_torrent: zamunda_torrent)
  end

  def edit(conn, %{"id" => id}) do
    zamunda_torrent = Repo.get!(ZamundaTorrent, id)
    changeset = ZamundaTorrent.changeset(zamunda_torrent)
    render(conn, "edit.html", zamunda_torrent: zamunda_torrent, changeset: changeset)
  end

  def update(conn, %{"id" => id, "zamunda_torrent" => zamunda_torrent_params}) do
    zamunda_torrent = Repo.get!(ZamundaTorrent, id)
    changeset = ZamundaTorrent.changeset(zamunda_torrent, zamunda_torrent_params)

    case Repo.update(changeset) do
      {:ok, zamunda_torrent} ->
        conn
        |> put_flash(:info, "Zamunda torrent updated successfully.")
        |> redirect(to: zamunda_torrent_path(conn, :show, zamunda_torrent))
      {:error, changeset} ->
        render(conn, "edit.html", zamunda_torrent: zamunda_torrent, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    zamunda_torrent = Repo.get!(ZamundaTorrent, id)

    # Here we use delete! (with a bang) because we expect
    # it to always work (and if it does not, it will raise).
    Repo.delete!(zamunda_torrent)

    conn
    |> put_flash(:info, "Zamunda torrent deleted successfully.")
    |> redirect(to: zamunda_torrent_path(conn, :index))
  end
end
