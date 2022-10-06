defmodule Mix.Tasks.Certbot do
  use Mix.Task

  alias Couloir42ReverseProxy.Certbot

  @impl Mix.Task
  def run(_args) do
    Mix.shell().info("Executing certbot ...")

    case Certbot.refresh() do
      {:warning, reason, warning_results} ->
        _ = Mix.shell().error(reason)

        _ =
          warning_results
          |> Enum.each(fn {:warning, reason, _certificate} -> _ = Mix.shell().error(reason) end)

        :warning

      {:error, reason} ->
        _ = Mix.shell().error(reason)

        :error

      {:error, reason, error_results} ->
        _ = Mix.shell().error(reason)

        _ =
          error_results
          |> Enum.each(fn {_level, reason} -> _ = Mix.shell().error(reason) end)

        :error

      :ok ->
        Mix.shell().info("Done.")
        :ok
    end
  end
end
