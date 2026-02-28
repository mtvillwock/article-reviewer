defmodule Pipeline.LLM.AnthropicClient do
  require Logger

  @base_url "https://api.anthropic.com/v1"
  @pricing %{
    "claude-haiku-4-5-20251001" => %{input: 0.25, output: 1.25},
    "claude-sonnet-4-5-20250929" => %{input: 3.00, output: 15.00},
    "claude-opus-4-5-20251101" => %{input: 15.00, output: 75.00}
  }

  def create_message(opts) do
    model = Keyword.fetch!(opts, :model)
    messages = Keyword.fetch!(opts, :messages)
    max_tokens = Keyword.fetch!(opts, :max_tokens)
    temperature = Keyword.get(opts, :temperature, 1.0)
    system = Keyword.get(opts, :system)

    api_key = get_api_key()

    body = %{model: model, messages: messages, max_tokens: max_tokens, temperature: temperature}
    body = if system, do: Map.put(body, :system, system), else: body

    headers = [
      {"Content-Type", "application/json"},
      {"x-api-key", api_key},
      {"anthropic-version", "2023-06-01"}
    ]

    url = "#{@base_url}/messages"

    case HTTPoison.post(url, Jason.encode!(body), headers,
           timeout: 120_000,
           recv_timeout: 120_000
         ) do
      {:ok, %{status_code: 200, body: response_body}} ->
        {:ok, Jason.decode!(response_body)}

      {:ok, %{status_code: 429}} ->
        {:error, :rate_limited}

      {:ok, %{status_code: status, body: response_body}} ->
        Logger.error("Anthropic API error #{status}: #{response_body}")
        {:error, {:api_error, status}}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, {:http_error, reason}}
    end
  end

  def calculate_cost(model, input_tokens, output_tokens) do
    pricing = Map.get(@pricing, model)

    if pricing do
      input_cost =
        Decimal.new(input_tokens)
        |> Decimal.mult(Decimal.from_float(pricing.input))
        |> Decimal.div(Decimal.new(1_000_000))

      output_cost =
        Decimal.new(output_tokens)
        |> Decimal.mult(Decimal.from_float(pricing.output))
        |> Decimal.div(Decimal.new(1_000_000))

      Decimal.add(input_cost, output_cost)
    else
      Decimal.new(0)
    end
  end

  defp get_api_key do
    Application.get_env(:pipeline, :anthropic)[:api_key] ||
      System.get_env("ANTHROPIC_API_KEY") ||
      raise "ANTHROPIC_API_KEY not configured"
  end
end
