defmodule Torr.TrackerController do
  use Torr.Web, :controller

  alias Torr.Tracker

  def index(conn, _params) do
    trackers = Repo.all(Tracker)
    render(conn, "index.html", trackers: trackers)
  end

  def new(conn, _params) do
    changeset = Tracker.changeset(%Tracker{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"tracker" => tracker_params}) do
    tracker_params = Torr.EncodeHelper.decode(tracker_params, "patterns")
    changeset = Tracker.changeset(%Tracker{}, tracker_params)

    case Repo.insert(changeset) do
      {:ok, _tracker} ->
        conn
        |> put_flash(:info, "Tracker created successfully.")
        |> redirect(to: tracker_path(conn, :index))
      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    tracker = Repo.get!(Tracker, id)
    render(conn, "show.html", tracker: tracker)
  end

  def edit(conn, %{"id" => id}) do
    tracker = Repo.get!(Tracker, id)
    changeset = Tracker.changeset(tracker)
    render(conn, "edit.html", tracker: tracker, changeset: changeset)
  end

  def update(conn, %{"id" => id, "tracker" => tracker_params}) do
    tracker = Repo.get!(Tracker, id)

    tracker_params = Torr.EncodeHelper.decode(tracker_params, "patterns")
    changeset = Tracker.changeset(tracker, tracker_params)

    case Repo.update(changeset) do
      {:ok, tracker} ->
        conn
        |> put_flash(:info, "Tracker updated successfully.")
        |> redirect(to: tracker_path(conn, :show, tracker))
      {:error, changeset} ->
        render(conn, "edit.html", tracker: tracker, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    tracker = Repo.get!(Tracker, id)

    # Here we use delete! (with a bang) because we expect
    # it to always work (and if it does not, it will raise).
    Repo.delete!(tracker)

    conn
    |> put_flash(:info, "Tracker deleted successfully.")
    |> redirect(to: tracker_path(conn, :index))
  end
end
