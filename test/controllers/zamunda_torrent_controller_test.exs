defmodule Torr.ZamundaTorrentControllerTest do
  use Torr.ConnCase

  alias Torr.ZamundaTorrent
  @valid_attrs %{content_html: "some content", name: "some content", page: 42, torrent_id: 42, tracker_id: 42}
  @invalid_attrs %{}

  test "lists all entries on index", %{conn: conn} do
    conn = get conn, zamunda_torrent_path(conn, :index)
    assert html_response(conn, 200) =~ "Listing zamunda torrents"
  end

  test "renders form for new resources", %{conn: conn} do
    conn = get conn, zamunda_torrent_path(conn, :new)
    assert html_response(conn, 200) =~ "New zamunda torrent"
  end

  test "creates resource and redirects when data is valid", %{conn: conn} do
    conn = post conn, zamunda_torrent_path(conn, :create), zamunda_torrent: @valid_attrs
    assert redirected_to(conn) == zamunda_torrent_path(conn, :index)
    assert Repo.get_by(ZamundaTorrent, @valid_attrs)
  end

  test "does not create resource and renders errors when data is invalid", %{conn: conn} do
    conn = post conn, zamunda_torrent_path(conn, :create), zamunda_torrent: @invalid_attrs
    assert html_response(conn, 200) =~ "New zamunda torrent"
  end

  test "shows chosen resource", %{conn: conn} do
    zamunda_torrent = Repo.insert! %ZamundaTorrent{}
    conn = get conn, zamunda_torrent_path(conn, :show, zamunda_torrent)
    assert html_response(conn, 200) =~ "Show zamunda torrent"
  end

  test "renders page not found when id is nonexistent", %{conn: conn} do
    assert_error_sent 404, fn ->
      get conn, zamunda_torrent_path(conn, :show, -1)
    end
  end

  test "renders form for editing chosen resource", %{conn: conn} do
    zamunda_torrent = Repo.insert! %ZamundaTorrent{}
    conn = get conn, zamunda_torrent_path(conn, :edit, zamunda_torrent)
    assert html_response(conn, 200) =~ "Edit zamunda torrent"
  end

  test "updates chosen resource and redirects when data is valid", %{conn: conn} do
    zamunda_torrent = Repo.insert! %ZamundaTorrent{}
    conn = put conn, zamunda_torrent_path(conn, :update, zamunda_torrent), zamunda_torrent: @valid_attrs
    assert redirected_to(conn) == zamunda_torrent_path(conn, :show, zamunda_torrent)
    assert Repo.get_by(ZamundaTorrent, @valid_attrs)
  end

  test "does not update chosen resource and renders errors when data is invalid", %{conn: conn} do
    zamunda_torrent = Repo.insert! %ZamundaTorrent{}
    conn = put conn, zamunda_torrent_path(conn, :update, zamunda_torrent), zamunda_torrent: @invalid_attrs
    assert html_response(conn, 200) =~ "Edit zamunda torrent"
  end

  test "deletes chosen resource", %{conn: conn} do
    zamunda_torrent = Repo.insert! %ZamundaTorrent{}
    conn = delete conn, zamunda_torrent_path(conn, :delete, zamunda_torrent)
    assert redirected_to(conn) == zamunda_torrent_path(conn, :index)
    refute Repo.get(ZamundaTorrent, zamunda_torrent.id)
  end
end
