defmodule Torr.TorrentTest do
  use Torr.ModelCase

  alias Torr.Torrent

  @valid_attrs %{html: "some content", json: %{}, name: "some content", url: "some content"}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = Torrent.changeset(%Torrent{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = Torrent.changeset(%Torrent{}, @invalid_attrs)
    refute changeset.valid?
  end
end
