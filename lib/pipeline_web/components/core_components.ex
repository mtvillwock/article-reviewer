defmodule PipelineWeb.CoreComponents do
  use Phoenix.Component

  attr(:flash, :map, required: true)
  attr(:kind, :atom, required: true)

  def flash(assigns) do
    ~H"""
    <div
      :if={msg = Phoenix.Flash.get(@flash, @kind)}
      id={"flash-#{@kind}"}
      phx-click="lv:clear-flash"
      phx-value-key={@kind}
      role="alert"
      class={[
        "fixed top-4 right-4 z-50 p-4 rounded-lg shadow-lg max-w-md",
        @kind == :info && "bg-blue-50 text-blue-900 border border-blue-200",
        @kind == :error && "bg-red-50 text-red-900 border border-red-200"
      ]}
    >
      <p class="text-sm font-medium"><%= msg %></p>
    </div>
    """
  end

  def flash_group(assigns) do
    ~H"""
    <div>
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />
    </div>
    """
  end
end
