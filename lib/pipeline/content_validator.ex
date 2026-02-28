defmodule Pipeline.ContentValidator do
  require Logger

  def validate(content, _url) when is_binary(content) do
    content = String.trim(content)

    with :ok <- check_minimum_length(content),
         :ok <- check_javascript_placeholders(content),
         :ok <- check_error_pages(content) do
      {:ok, content}
    end
  end

  defp check_minimum_length(content) do
    word_count = content |> String.split() |> length()

    if word_count < 50 do
      {:error, :insufficient_content, "Only #{word_count} words found (minimum 50 required)"}
    else
      :ok
    end
  end

  defp check_javascript_placeholders(content) do
    js_indicators = ["Loading...", "Please enable JavaScript", "JavaScript is required"]
    indicator_count = Enum.count(js_indicators, &String.contains?(content, &1))
    word_count = content |> String.split() |> length()

    if indicator_count >= 2 and word_count < 300 do
      {:error, :javascript_required, "Content appears to require JavaScript rendering"}
    else
      :ok
    end
  end

  defp check_error_pages(content) do
    content_lower = String.downcase(content)

    cond do
      String.contains?(content_lower, "404") or String.contains?(content_lower, "not found") ->
        {:error, :not_found, "Page not found (404)"}

      String.contains?(content_lower, "403") or String.contains?(content_lower, "forbidden") ->
        {:error, :forbidden, "Access forbidden (403)"}

      true ->
        :ok
    end
  end

  def suggest_retry_strategy(error_type) do
    case error_type do
      :javascript_required -> {:retry, :reader_api}
      :insufficient_content -> {:retry, :reader_api}
      :timeout -> {:retry, :reader_api}
      :not_found -> {:skip, "Page does not exist"}
      :forbidden -> {:retry, :reader_api}
      _ -> {:manual_review, "Unknown error"}
    end
  end

  def strategy_name(:direct), do: "Direct HTTP"
  def strategy_name(:reader_api), do: "Reader API"
  def strategy_name(:manual), do: "Manual Input"
  def strategy_name(_), do: "Unknown"
end
