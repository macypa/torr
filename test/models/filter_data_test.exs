defmodule Torr.FilterDataTest do
  use Torr.ModelCase

  alias Torr.FilterData

  @valid_attrs %{key: "some content", value: "some content"}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = FilterData.changeset(%FilterData{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = FilterData.changeset(%FilterData{}, @invalid_attrs)
    refute changeset.valid?
  end
end
