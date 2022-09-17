defmodule Couloir42ReverseProxy.RouterSSL do
  use Plug.Router

  alias Couloir42ReverseProxy.Upstream
  alias Couloir42ReverseProxy.Upstreams
  alias Couloir42ReverseProxy.Passwords

  plug(Plug.Logger)

  if Mix.env() in [:dev, :test] do
    plug(Plug.SSL, hsts: false)
  else
    plug(Plug.SSL, hsts: true, secure_renegotiate: true, reuse_sessions: true)
  end

  if Passwords.compiled_read() |> Enum.any?() do
    plug(Couloir42ReverseProxy.BasicAuth)
  end

  plug(:match)
  plug(:dispatch)

  plug(Couloir42ReverseProxy.BeforeForward)

  for %Upstream{match_domain: x, upstream: y} <- Upstreams.read(persist: false) do
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