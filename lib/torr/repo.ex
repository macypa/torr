defmodule Torr.Repo do
  use Ecto.Repo, otp_app: :torr
  use Scrivener, page_size: 50
end
