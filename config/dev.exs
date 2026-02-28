import Config

config :pipeline, Pipeline.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "pipeline_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :pipeline, PipelineWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "dev_secret_key_base_at_least_64_bytes_long_for_security_purposes",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:pipeline, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:pipeline, ~w(--watch)]}
  ]

config :pipeline, PipelineWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"lib/pipeline_web/(live|components)/.*(ex|heex)$"
    ]
  ]

config :logger, :console, format: "[$level] $message\n"
config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime
config :phoenix_live_view, debug_heex_annotations: true
