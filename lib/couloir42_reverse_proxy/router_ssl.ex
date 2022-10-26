defmodule Couloir42ReverseProxy.RouterSSL do
  use Plug.Router

  alias Couloir42ReverseProxy.Upstream
  alias Couloir42ReverseProxy.Upstreams
  alias Couloir42ReverseProxy.Passwords

  plug(Plug.Telemetry, event_prefix: [:proxy, :request])
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

  for %Upstream{match_domain: x, upstream: y} <- Upstreams.compiled_read(persist: false) do
    forward("/",
      host: x,
      to: ReverseProxyPlug,
      upstream: URI.to_string(y)
    )
  end

  match _ do
    conn
    |> Plug.Conn.resp(302, "")
    |> Plug.Conn.put_resp_header("location", "http://www.perdu.com")
  end
end
