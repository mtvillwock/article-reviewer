import Config

config :pipeline, Pipeline.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "pipeline_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

config :pipeline, PipelineWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test_secret_key_base",
  server: false

config :logger, level: :warning
config :phoenix, :plug_init_mode, :runtime
