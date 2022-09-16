defmodule Couloir42ReverseProxy.Upstreams do
  use Agent

  require Logger

  alias Couloir42ReverseProxy.Upstream
  alias Couloir42ReverseProxy.Certbot
  alias Couloir42ReverseProxy.Certificate
  alias Couloir42ReverseProxy.KeyValueParser

  def start_link(_initial_value) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  @doc """
    Finds the upstream matching the given hostname.
  """
  @spec sni(bitstring()) :: keyword()
  def sni(hostname) do
    find(hostname)
    |> select_certificate()
    |> to_options()
  end

  @doc """
    Reads and parses the upstreams defined in the UPSTREAMS environment variables.
  """
  @spec read() :: list(Upstream.t())
  def read(), do: internal_read() |> Map.values()

  @doc """
    Reads and parses the upstreams defined in the UPSTREAMS environment variables.
  """
  @spec compiled_read() :: list(Upstream.t())
  def compiled_read() do
    {before, _after} = load(%{})
    before |> Map.values()
  end

  @doc """
   Finds and parses the upstreams and returns only the upstream which matches the hostname.
  """
  @spec find(bitstring() | charlist()) :: {:ok, Upstream.t()} | :not_found
  def find(hostname) when is_bitstring(hostname) do
    case internal_read() |> Map.fetch(String.downcase(hostname)) do
      :error -> :not_found
      {:ok, x} -> {:ok, x}
    end
  end

  def find(hostname) when is_list(hostname), do: find(to_string(hostname))

  # Internal

  defp internal_read(), do: Agent.get_and_update(__MODULE__, &load/1)

  defp load(state) when is_map(state) and map_size(state) > 0,
    do: {state, state}

  defp load(state) when is_map(state) do
    Logger.info("Loading upstreams ...")

    upstreams =
      KeyValueParser.read(
        "UPSTREAMS",
        fn {key, value} ->
          {:ok,
           %Upstream{
             match_domain: String.downcase(key),
             upstream: URI.parse(value)
           }}
        end
      )

    Logger.info("Done.")

    new_state =
      state |> Map.merge(Map.new(upstreams, fn %Upstream{match_domain: key} = x -> {key, x} end))

    {new_state, new_state}
  end

  defp select_certificate(:not_found), do: :not_found

  defp select_certificate({:ok, %Upstream{match_domain: x}}) do
    Certbot.read_certificates()
    |> Enum.filter(fn %Certificate{domains: domains} ->
      domains
      |> Enum.filter(fn domain -> String.equivalent?(domain, x) end)
      |> Enum.any?()
    end)
    |> Enum.at(0)
  end

  defp to_options(:not_found), do: :undefined
  defp to_options(nil), do: :undefined

  defp to_options(%Certificate{path: path, key_path: key_path}) do
    [
      certfile: path,
      keyfile: key_path
    ]
  end
end
