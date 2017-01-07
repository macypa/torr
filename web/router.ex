defmodule Torr.Router do
  use Torr.Web, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", Torr do
    pipe_through :browser # Use the default browser stack

    #get "/", TorrentController, :index
    resources "/torrents", TorrentController#, only: [:index, :show]

    get "/*path", RedirectController, :redirector
  end

  # Other scopes may use custom stacks.
  # scope "/api", Torr do
  #   pipe_through :api
  # end
end

defmodule Torr.RedirectController do
  use Torr.Web, :controller
  @send_to "/torrents"

  def redirector(conn, _params), do: redirect(conn, to: @send_to)

end