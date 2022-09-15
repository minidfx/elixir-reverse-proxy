defmodule Couloir42ReverseProxy.Upstreams do
  alias Couloir42ReverseProxy.Upstream
  alias Couloir42ReverseProxy.Certbot
  alias Couloir42ReverseProxy.Certificate

  require Logger

  @spec sni(bitstring()) :: keyword()
  def sni(hostname) do
    find(hostname)
    |> select_certificate(hostname)
    |> to_options()
  end

  @doc """
    Reads and parses the upstreams defined in the UPSTREAMS environment variables.
  """
  @spec read() :: list(Upstream.t())
  def read() do
    System.get_env("UPSTREAMS") |> parse_upstreams()
  end

  @doc """
   Finds and parses the upstreams and returns only the upstream which matches the hostname.
  """
  @spec find(bitstring() | charlist()) :: {:ok, Upstream.t()} | :not_found
  def find(hostname) when is_bitstring(hostname) do
    local_hostname = String.downcase(hostname)

    case read() |> Enum.find(fn %Upstream{match_domain: x} -> x == local_hostname end) do
      nil -> :not_found
      x -> {:ok, x}
    end
  end

  def find(hostname) when is_list(hostname), do: find(to_string(hostname))

  # Internal

  defp select_certificate(:not_found, hostname) do
    raise "The upstream for the #{hostname} was not found."
  end

  defp select_certificate({:ok, %Upstream{match_domain: x}}, _hostname) do
    Certbot.read_certificates()
    |> Enum.filter(fn %Certificate{domains: domains} ->
      domains
      |> Enum.filter(fn domain -> domain == x end)
      |> Enum.any?()
    end)
    |> Enum.at(0)
  end

  defp parse_upstreams(nil), do: []

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
    {:ok, %Upstream{match_domain: String.downcase(match_domain), upstream: URI.parse(upstream)}}
  end

  defp create_upstream!(unknown) do
    error_message = unknown |> Enum.join(",")
    {:error, "invalid upstream: #{error_message}"}
  end

  defp to_options(nil), do: :undefined

  defp to_options(%Certificate{path: path, key_path: key_path}) do
    [
      certfile: path,
      keyfile: key_path
    ]
  end
end
