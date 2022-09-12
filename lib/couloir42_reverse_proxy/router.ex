defmodule Couloir42ReverseProxy.Router do
  use Plug.Router

  alias Couloir42ReverseProxy.Upstream
  alias Couloir42ReverseProxy.Upstreams

  if Mix.env() in [:dev, :test] do
    plug(Plug.SSL, hsts: false)
    plug(Plug.Logger)
  else
    plug(Plug.SSL, hsts: true, secure_renegotiate: true, reuse_sessions: true)
  end

  plug(:match)
  plug(:dispatch)

  plug(Couloir42ReverseProxy.BeforeForward)

  for %Upstream{match_domain: x, upstream: y} <- Upstreams.read() do
    forward("/",
      host: x,
      to: ReverseProxyPlug,
      upstream: URI.to_string(y)
    )
  end

  match _ do
    send_resp(conn, 404, "oops")
  end
end
