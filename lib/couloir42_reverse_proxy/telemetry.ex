defmodule Couloir42ReverseProxy.Telemetry do
  require Logger

  def handle_event([:proxy, :request, :start], _measurements, metadata, _config) do
    %{conn: conn} = metadata

    Logger.info("#{ip(conn)} is requesting #{uri(conn)} ...")
  end

  def handle_event(_events, _measurements, _metadata, _config) do
    :ok
  end

  defp ip(%Plug.Conn{remote_ip: ip}) do
    {a, b, c, d} = ip
    "#{a}.#{b}.#{c}.#{d}"
  end

  defp uri(%Plug.Conn{scheme: scheme, host: host, port: port, request_path: path}),
    do: "#{scheme}://#{host}:#{port}#{path}"
end
