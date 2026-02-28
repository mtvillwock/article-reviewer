defmodule PipelineWeb.ArticleLive do
  use PipelineWeb, :live_view
  alias Pipeline.{Repo, PipelineCoordinator}
  alias Pipeline.Schemas.Article
  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Pipeline.PubSub, "article:fetch_success")
      Phoenix.PubSub.subscribe(Pipeline.PubSub, "article:fetch_failed")
      Phoenix.PubSub.subscribe(Pipeline.PubSub, "article:complete")
    end

    {:ok,
     socket
     |> assign(:articles, list_articles())
     |> assign(:url_input, "")
     |> assign(:selected_article, nil)
     |> assign(:page_title, "AI Article Pipeline")}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    article = PipelineCoordinator.get_article_analysis(String.to_integer(id))
    {:noreply, assign(socket, :selected_article, article)}
  end

  @impl true
  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  @impl true
  def handle_event("submit_url", %{"url" => url}, socket) do
    case PipelineCoordinator.process_url(url) do
      {:ok, _article} ->
        {:noreply, socket |> assign(:url_input, "") |> put_flash(:info, "Processing...")}

      {:error, _, details, _} ->
        {:noreply, put_flash(socket, :error, details)}
    end
  end

  @impl true
  def handle_event("select_article", %{"id" => id}, socket) do
    article = PipelineCoordinator.get_article_analysis(String.to_integer(id))
    {:noreply, assign(socket, :selected_article, article)}
  end

  @impl true
  def handle_event("retry_article", %{"id" => id}, socket) do
    case PipelineCoordinator.retry_article(String.to_integer(id)) do
      {:ok, _} -> {:noreply, put_flash(socket, :info, "Retrying...")}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Cannot retry")}
    end
  end

  @impl true
  def handle_info({:fetch_success, _}, socket) do
    {:noreply, assign(socket, :articles, list_articles())}
  end

  @impl true
  def handle_info({:fetch_failed, _, _, _}, socket) do
    {:noreply, assign(socket, :articles, list_articles())}
  end

  @impl true
  def handle_info({:article_complete, _}, socket) do
    {:noreply, socket |> assign(:articles, list_articles()) |> put_flash(:info, "Complete!")}
  end

  defp list_articles do
    from(a in Article,
      order_by: [desc: a.inserted_at],
      limit: 50,
      preload: [:tier_1_classification, :workflow_cost]
    )
    |> Repo.all()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 p-8">
      <div class="max-w-7xl mx-auto">
        <h1 class="text-3xl font-bold text-gray-900 mb-8">AI Article Analysis Pipeline</h1>

        <form phx-submit="submit_url" class="mb-8 flex gap-4">
          <input type="url" name="url" value={@url_input}
                 placeholder="https://example.com/article" required
                 class="flex-1 rounded-lg border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500" />
          <button type="submit"
                  class="px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 font-medium">
            Analyze Article
          </button>
        </form>

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <div class="lg:col-span-1 bg-white rounded-lg shadow">
            <div class="px-6 py-4 border-b border-gray-200">
              <h2 class="text-lg font-semibold">Recent Articles</h2>
            </div>
            <div class="divide-y divide-gray-200 max-h-[600px] overflow-y-auto">
              <%= for article <- @articles do %>
                <button phx-click="select_article" phx-value-id={article.id}
                        class={["w-full text-left px-6 py-4 hover:bg-gray-50 transition",
                                @selected_article && @selected_article.id == article.id && "bg-blue-50"]}>
                  <p class="text-sm font-medium text-gray-900 truncate">
                    <%= article.title || article.url %>
                  </p>
                  <div class="mt-2 flex items-center gap-2">
                    <span class={["text-xs px-2 py-1 rounded-full",
                                  status_color(article.status)]}>
                      <%= article.status %>
                    </span>
                    <%= if article.workflow_cost do %>
                      <span class="text-xs text-gray-500">
                        $<%= Decimal.to_string(article.workflow_cost.total_cost, :normal) %>
                      </span>
                    <% end %>
                  </div>
                </button>
              <% end %>
            </div>
          </div>

          <div class="lg:col-span-2 bg-white rounded-lg shadow p-6">
            <%= if @selected_article do %>
              <h2 class="text-xl font-bold mb-4"><%= @selected_article.title %></h2>
              <p class="text-sm text-gray-600 mb-4">Status: <%= @selected_article.status %></p>

              <%= if @selected_article.status == "fetch_failed" do %>
                <div class="bg-red-50 border border-red-200 rounded p-4 mb-4">
                  <p class="font-semibold text-red-900">Failed to fetch article</p>
                  <p class="text-red-800 mb-2">
                    <%= Article.format_error(@selected_article) %>
                  </p>
                  <%= if Article.can_retry?(@selected_article) do %>
                    <button phx-click="retry_article" phx-value-id={@selected_article.id}
                      class="mt-3 px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700">
                      Retry with Reader API
                    </button>
                  <% end %>
                </div>
              <% end %>

              <%= if @selected_article.tier_1_classification do %>
                <div class="mb-6">
                  <h3 class="text-lg font-semibold mb-3">Classification</h3>
                  <div class="grid grid-cols-2 gap-4 text-sm">
                    <div><span class="text-gray-600">Type:</span>
                      <span class="ml-2 font-medium"><%= @selected_article.tier_1_classification.content_type %></span>
                    </div>
                    <div><span class="text-gray-600">Complexity:</span>
                      <span class="ml-2 font-medium"><%= @selected_article.tier_1_classification.complexity %></span>
                    </div>
                  </div>
                </div>
              <% end %>

              <%= if @selected_article.tier_3_deep_analysis do %>
                <div class="mb-6">
                  <h3 class="text-lg font-semibold mb-3">Deep Analysis</h3>
                  <div class="prose max-w-none">
                    <p class="whitespace-pre-wrap"><%= @selected_article.tier_3_deep_analysis.executive_summary %></p>
                  </div>
                </div>
              <% end %>

              <%= if @selected_article.tier_2_5_actionability do %>
                <div class="mb-6">
                  <h3 class="text-lg font-semibold mb-3">Implementation Guide</h3>
                  <div class="prose max-w-none">
                    <%= raw Earmark.as_html!(@selected_article.tier_2_5_actionability.one_sentence_essence) %>
                  </div>
                </div>
              <% end %>
            <% else %>
              <p class="text-gray-500 text-center py-12">
                Select an article to view analysis
              </p>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp status_color("complete"), do: "bg-green-100 text-green-800"
  defp status_color("processing"), do: "bg-blue-100 text-blue-800"
  defp status_color("fetched"), do: "bg-indigo-100 text-indigo-800"
  defp status_color("fetch_failed"), do: "bg-red-100 text-red-800"
  defp status_color("skipped"), do: "bg-gray-100 text-gray-800"
  defp status_color(_), do: "bg-yellow-100 text-yellow-800"
end
