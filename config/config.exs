import Config

config :pipeline,
  ecto_repos: [Pipeline.Repo],
  generators: [timestamp_type: :utc_datetime]

config :pipeline, PipelineWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [formats: [html: PipelineWeb.ErrorHTML], layout: false],
  pubsub_server: Pipeline.PubSub,
  live_view: [signing_salt: "xK8vN9pM"]

config :esbuild,
  version: "0.17.11",
  pipeline: [
    args: ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :tailwind,
  version: "3.4.0",
  pipeline: [
    args:
      ~w(--config=tailwind.config.js --input=css/app.css --output=../priv/static/assets/app.css),
    cd: Path.expand("../assets", __DIR__)
  ]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

config :pipeline,
  anthropic: [
    api_key: System.get_env("ANTHROPIC_API_KEY"),
    base_url: "https://api.anthropic.com/v1"
  ]

config :pipeline,
  reader_api: [
    jina_enabled: true,
    jina_base_url: "https://r.jina.ai",
    timeout: 45_000
  ]

import_config "#{config_env()}.exs"
