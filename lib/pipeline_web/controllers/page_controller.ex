defmodule PipelineWeb.PageController do
  use PipelineWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
