defmodule Torr.Router do
  require Logger
  use Torr.Web, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :put_user_token
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

  defp put_user_token(conn, _) do
    user_id_token = Phoenix.Token.sign(conn, "user_id", get_session(conn, :key))
    Logger.debug "put_user_token user_id_token: #{inspect(user_id_token)}"
    assign(conn, :user_id, user_id_token)
#    conn |> assign(:user_id, user_id_token)
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