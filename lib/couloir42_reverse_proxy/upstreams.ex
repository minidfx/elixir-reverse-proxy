defmodule Couloir42ReverseProxy.Upstreams do
  alias Couloir42ReverseProxy.Upstream

  require Logger

  @spec read :: list(Upstream.t())
  def read() do
    System.get_env("UPSTREAMS") |> parse_upstreams()
  end

  defp parse_upstreams(nil) do
    []
  end

  defp parse_upstreams(raw) when is_bitstring(raw) do
    raw
    |> String.split(",", trim: true)
    |> Enum.map(fn x -> x |> String.split("=") |> create_upstream!() end)
    |> Enum.filter(&filter_invalid_upstream/1)
    |> Enum.map(fn {:ok, upstream} -> upstream end)
  end

  defp filter_invalid_upstream({:error, reason}) do
    Logger.warn(reason)
    false
  end

  defp filter_invalid_upstream({:ok, _upstream}) do
    true
  end

  defp create_upstream!([match_domain, upstream]) do
    {:ok, %Upstream{match_domain: match_domain, upstream: URI.parse(upstream)}}
  end

  defp create_upstream!(unknown) do
    error_message = unknown |> Enum.join(",")
    {:error, "invalid upstream: #{error_message}"}
  end
end
