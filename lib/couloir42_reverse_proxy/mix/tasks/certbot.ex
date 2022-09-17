defmodule Mix.Tasks.Certbot do
  use Mix.Task

  require Logger

  alias Couloir42ReverseProxy.Certbot

  @impl Mix.Task
  def run(_args) do
    case Certbot.refresh() do
      {:error, reason} ->
        Logger.error(reason)

      :ok ->
        :ok
    end
  end
end
