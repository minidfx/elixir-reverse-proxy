defmodule Couloir42ReverseProxy.Router do
  use Plug.Router

  if Mix.env() in [:dev, :test] do
    plug(Plug.Logger)
  end

  plug(:match)
  plug(:dispatch)

  forward("/", to: ReverseProxyPlug, upstream: "//192.168.1.155:9001")
end
