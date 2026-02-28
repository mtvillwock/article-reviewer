defmodule PipelineWeb.Router do
  use PipelineWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PipelineWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", PipelineWeb do
    pipe_through :browser
    live "/", ArticleLive, :index
    live "/articles/:id", ArticleLive, :show
  end
end
