defmodule Torr.ZamundaTorrentTest do
  use Torr.ModelCase

  alias Torr.ZamundaTorrent

  @valid_attrs %{content_html: "some content", name: "some content", page: 42, torrent_id: 42, tracker_id: 42}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = ZamundaTorrent.changeset(%ZamundaTorrent{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = ZamundaTorrent.changeset(%ZamundaTorrent{}, @invalid_attrs)
    refute changeset.valid?
  end
end
