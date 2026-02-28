defmodule Pipeline.Repo do
  use Ecto.Repo,
    otp_app: :pipeline,
    adapter: Ecto.Adapters.Postgres
end
