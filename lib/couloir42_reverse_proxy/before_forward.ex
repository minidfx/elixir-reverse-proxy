defmodule Couloir42ReverseProxy.BeforeForward do
  @spec init(any) :: any
  def init(options) do
    # initialize options
    options
  end

  @spec call(Plug.Conn.t(), any) :: Plug.Conn.t()
  def call(conn, _opts) do
    # INFO: Hook for disabling/enabling the proxy.
    conn
  end
end
