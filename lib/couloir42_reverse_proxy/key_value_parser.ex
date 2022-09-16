defmodule Couloir42ReverseProxy.KeyValueParser do
  require Logger

  @doc """
    Reads and parses key value settings.
  """
  @spec read(String.t(), ({String.t(), String.t()} -> {:ok, any} | {:error, String.t()})) ::
          list(any)
  def read(environment_variable_name, model_factory)
      when is_bitstring(environment_variable_name) do
    System.get_env(environment_variable_name) |> parse(model_factory)
  end

  # Internal

  defp parse(nil, _model_factory), do: []

  defp parse(raw, model_factory)
       when is_bitstring(raw) and is_function(model_factory) do
    raw
    |> String.split(",", trim: true)
    |> Enum.map(fn x ->
      x
      |> String.split("=", trim: true, parts: 2)
      |> only_2_items()
      |> create_model(model_factory)
    end)
    |> Enum.filter(&filter_invalid/1)
    |> Enum.map(fn {:ok, result} -> result end)
  end

  defp only_2_items([key, value]), do: {:ok, {key, value}}

  defp only_2_items(unknown) when is_list(unknown) do
    items = unknown |> Enum.join(",")
    {:error, "Cannot identify key and value: #{items}"}
  end

  defp create_model({:error, _} = error, _model_factory), do: error
  defp create_model({:ok, keyValue}, model_factory), do: model_factory.(keyValue)

  defp filter_invalid({:ok, _}), do: true

  defp filter_invalid({:error, reason}) do
    Logger.warn(reason)
    false
  end
end
