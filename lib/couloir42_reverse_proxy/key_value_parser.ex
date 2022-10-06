defmodule Couloir42ReverseProxy.KeyValueParser do
  @doc """
    Reads and parses key value settings.
  """
  @spec read(String.t(), ({String.t(), String.t()} -> {:ok, any} | {:error, String.t()})) :: list({String.t(), String.t()})
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
      |> String.split("=", trim: true)
      |> only_2_items()
      |> create_model(model_factory)
    end)
    |> Enum.filter(&match?({:ok, _}, &1))
    |> Enum.map(fn {:ok, result} -> result end)
  end

  defp only_2_items([key, value]), do: {:ok, {key, value}}
  defp only_2_items(unknown) when is_list(unknown), do: :skip

  defp create_model(:skip, _model_factory), do: :skip
  defp create_model({:ok, keyValue}, model_factory), do: model_factory.(keyValue)
end
