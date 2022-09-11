defmodule Couloir42ReverseProxy.Router do
  use Plug.Router

  plug(Plug.SSL, hsts: true)

  if Mix.env() in [:dev, :test] do
    plug(Plug.Logger)
  end

  plug(:match)
  plug(:dispatch)

  forward("/", to: ReverseProxyPlug, upstream: "http://192.168.1.155:9001")
end
