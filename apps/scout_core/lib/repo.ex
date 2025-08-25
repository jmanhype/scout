
defmodule Scout.Repo do
  use Ecto.Repo, otp_app: :scout_core, adapter: Ecto.Adapters.Postgres
end
