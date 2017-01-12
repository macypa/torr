defmodule Torr.Repo do
  use Ecto.Repo, otp_app: :torr
#  use Kerosene, per_page: 25
  use Scrivener, page_size: 25
end
