# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :torr,
  ecto_repos: [Torr.Repo]

# Configures the endpoint
config :torr, Torr.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "eKWME2hFj8Qe5DyK5fxB3s6QTvJmf83bMEQBnFZwoZ09/onZ0Q/iIaYlPaD4tahp",
  render_errors: [view: Torr.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Torr.PubSub,
           adapter: Phoenix.PubSub.PG2]

config :scrivener_html,
  routes_helper: MyApp.Router.Helpers

config :logger,
  backends: [{LoggerFileBackend, :file_log}, :console]
#config :logger, :file_log,
#  path: "debug.log",
#  level: :info

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id],
  level: :warn

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
