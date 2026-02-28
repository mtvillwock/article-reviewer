defmodule Pipeline.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PipelineWeb.Telemetry,
      Pipeline.Repo,
      {Phoenix.PubSub, name: Pipeline.PubSub},
      {Finch, name: Pipeline.Finch},
      PipelineWeb.Endpoint,
      Pipeline.Agents.RouterAgent,
      Pipeline.Agents.QuickScanAgent,
      Pipeline.Agents.ActionabilityAgent,
      Pipeline.Agents.DeepAnalysisAgent
    ]

    opts = [strategy: :one_for_one, name: Pipeline.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    PipelineWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
