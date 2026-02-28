defmodule Pipeline.ReaderApiClient do
  require Logger

  def fetch(url) do
    with {:error, _} <- try_jina(url) do
      {:error, :all_reader_apis_failed}
    end
  end

  defp try_jina(url) do
    Logger.info("Trying Jina AI Reader for #{url}")
    jina_url = "https://r.jina.ai/#{url}"
    headers = [{"Accept", "application/json"}]

    case HTTPoison.get(jina_url, headers, timeout: 45_000, recv_timeout: 45_000) do
      {:ok, %{status_code: 200, body: body}} ->
        {:ok, %{title: "Article", content: body, url: url, extraction_method: "jina_ai"}}

      _ ->
        {:error, :jina_failed}
    end
  end
end
