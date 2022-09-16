defmodule Couloir42ReverseProxy.Passwords do
  use Agent

  require Logger

  alias Couloir42ReverseProxy.Password
  alias Couloir42ReverseProxy.KeyValueParser

  def start_link(_initial_value) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  @spec read() :: list(Password.t())
  def read(), do: internal_read() |> Map.values()

  @spec compiled_read() :: list(Password.t())
  def compiled_read() do
    {before, _after} = load(%{})
    before |> Map.values()
  end

  @doc """
   Finds the passwords matching the given hostname.
  """
  @spec find(bitstring() | charlist()) :: {:ok, Password.t()} | :not_found
  def find(hostname) when is_bitstring(hostname) do
    case internal_read() |> Map.fetch(String.downcase(hostname)) do
      :error -> :not_found
      {:ok, x} -> {:ok, x}
    end
  end

  # Internal

  defp internal_read(), do: Agent.get_and_update(__MODULE__, &load/1)

  defp load(state) when is_map(state) and map_size(state) > 0,
    do: {state, state}

  defp load(state) when is_map(state) do
    Logger.info("Loading passwords ...")

    passwords =
      KeyValueParser.read(
        "PASSWORDS",
        fn {key, value} ->
          {:ok,
           %Password{
             match_domain: String.downcase(key),
             encoded_password: value
           }}
        end
      )

    Logger.info("Done")

    new_state =
      state |> Map.merge(Map.new(passwords, fn %Password{match_domain: key} = x -> {key, x} end))

    {new_state, new_state}
  end
end
