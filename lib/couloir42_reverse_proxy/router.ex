defmodule Couloir42ReverseProxy.Router do
  use Plug.Router

  plug(Plug.SSL, hsts: true)

  if Mix.env() in [:dev, :test] do
    plug(Plug.Logger)
  end

  plug(:match)
  plug(:dispatch)

  for {match_domain, to} <-
        Application.compile_env(:couloir42_reverse_proxy, :upstreams, []) do
    forward("/",
      host: match_domain,
      to: ReverseProxyPlug,
      upstream: to
    )
  end

  match _ do
    send_resp(conn, 404, "oops")
  end
end
