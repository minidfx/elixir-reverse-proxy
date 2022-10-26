defmodule Couloir42ReverseProxy.BeforeForward do
  @behaviour Plug

  @impl true
  def init(options) do
    # initialize options
    options
  end

  @impl true
  def call(conn, _opts) do
    # INFO: Hook for disabling/enabling the proxy.
    conn
  end
end
