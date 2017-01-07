defmodule Torr.TorrentControllerTest do
  use Torr.ConnCase

  alias Torr.Torrent
  @valid_attrs %{html: %{}, name: "some content", url: "some content"}
  @invalid_attrs %{}

  test "lists all entries on index", %{conn: conn} do
    conn = get conn, torrent_path(conn, :index)
    assert html_response(conn, 200) =~ "Listing torrents"
  end

  test "renders form for new resources", %{conn: conn} do
    conn = get conn, torrent_path(conn, :new)
    assert html_response(conn, 200) =~ "New torrent"
  end

  test "creates resource and redirects when data is valid", %{conn: conn} do
    conn = post conn, torrent_path(conn, :create), torrent: @valid_attrs
    assert redirected_to(conn) == torrent_path(conn, :index)
    assert Repo.get_by(Torrent, @valid_attrs)
  end

  test "does not create resource and renders errors when data is invalid", %{conn: conn} do
    conn = post conn, torrent_path(conn, :create), torrent: @invalid_attrs
    assert html_response(conn, 200) =~ "New torrent"
  end

  test "shows chosen resource", %{conn: conn} do
    torrent = Repo.insert! %Torrent{}
    conn = get conn, torrent_path(conn, :show, torrent)
    assert html_response(conn, 200) =~ "Show torrent"
  end

  test "renders page not found when id is nonexistent", %{conn: conn} do
    assert_error_sent 404, fn ->
      get conn, torrent_path(conn, :show, -1)
    end
  end

  test "renders form for editing chosen resource", %{conn: conn} do
    torrent = Repo.insert! %Torrent{}
    conn = get conn, torrent_path(conn, :edit, torrent)
    assert html_response(conn, 200) =~ "Edit torrent"
  end

  test "updates chosen resource and redirects when data is valid", %{conn: conn} do
    torrent = Repo.insert! %Torrent{}
    conn = put conn, torrent_path(conn, :update, torrent), torrent: @valid_attrs
    assert redirected_to(conn) == torrent_path(conn, :show, torrent)
    assert Repo.get_by(Torrent, @valid_attrs)
  end

  test "does not update chosen resource and renders errors when data is invalid", %{conn: conn} do
    torrent = Repo.insert! %Torrent{}
    conn = put conn, torrent_path(conn, :update, torrent), torrent: @invalid_attrs
    assert html_response(conn, 200) =~ "Edit torrent"
  end

  test "deletes chosen resource", %{conn: conn} do
    torrent = Repo.insert! %Torrent{}
    conn = delete conn, torrent_path(conn, :delete, torrent)
    assert redirected_to(conn) == torrent_path(conn, :index)
    refute Repo.get(Torrent, torrent.id)
  end
end
