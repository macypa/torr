defmodule Torr.PageController do
  use Torr.Web, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
