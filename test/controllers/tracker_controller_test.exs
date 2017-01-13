defmodule Torr.TrackerControllerTest do
  use Torr.ConnCase

  alias Torr.Tracker
  @valid_attrs %{cookie: "some content", htmlPattern: "some content", lastPageNumber: 42, name: "some content", namePattern: "some content", pagePattern: "some content", patterns: %{}, url: "some content", urlPattern: "some content"}
  @invalid_attrs %{}

  test "lists all entries on index", %{conn: conn} do
    conn = get conn, tracker_path(conn, :index)
    assert html_response(conn, 200) =~ "Listing trackers"
  end

  test "renders form for new resources", %{conn: conn} do
    conn = get conn, tracker_path(conn, :new)
    assert html_response(conn, 200) =~ "New tracker"
  end

  test "creates resource and redirects when data is valid", %{conn: conn} do
    conn = post conn, tracker_path(conn, :create), tracker: @valid_attrs
    assert redirected_to(conn) == tracker_path(conn, :index)
    assert Repo.get_by(Tracker, @valid_attrs)
  end

  test "does not create resource and renders errors when data is invalid", %{conn: conn} do
    conn = post conn, tracker_path(conn, :create), tracker: @invalid_attrs
    assert html_response(conn, 200) =~ "New tracker"
  end

  test "shows chosen resource", %{conn: conn} do
    tracker = Repo.insert! %Tracker{}
    conn = get conn, tracker_path(conn, :show, tracker)
    assert html_response(conn, 200) =~ "Show tracker"
  end

  test "renders page not found when id is nonexistent", %{conn: conn} do
    assert_error_sent 404, fn ->
      get conn, tracker_path(conn, :show, -1)
    end
  end

  test "renders form for editing chosen resource", %{conn: conn} do
    tracker = Repo.insert! %Tracker{}
    conn = get conn, tracker_path(conn, :edit, tracker)
    assert html_response(conn, 200) =~ "Edit tracker"
  end

  test "updates chosen resource and redirects when data is valid", %{conn: conn} do
    tracker = Repo.insert! %Tracker{}
    conn = put conn, tracker_path(conn, :update, tracker), tracker: @valid_attrs
    assert redirected_to(conn) == tracker_path(conn, :show, tracker)
    assert Repo.get_by(Tracker, @valid_attrs)
  end

  test "does not update chosen resource and renders errors when data is invalid", %{conn: conn} do
    tracker = Repo.insert! %Tracker{}
    conn = put conn, tracker_path(conn, :update, tracker), tracker: @invalid_attrs
    assert html_response(conn, 200) =~ "Edit tracker"
  end

  test "deletes chosen resource", %{conn: conn} do
    tracker = Repo.insert! %Tracker{}
    conn = delete conn, tracker_path(conn, :delete, tracker)
    assert redirected_to(conn) == tracker_path(conn, :index)
    refute Repo.get(Tracker, tracker.id)
  end
end
