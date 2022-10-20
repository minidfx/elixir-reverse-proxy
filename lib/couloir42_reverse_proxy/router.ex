defmodule Couloir42ReverseProxy.Router do
  use Plug.Router

  plug(Plug.Logger)

  plug(Plug.Static, from: "priv/static/.well-known", at: "/.well-known")

  plug(:match)
  plug(:dispatch)

  match _ do
    conn
    |> Plug.Conn.resp(302, "")
    |> Plug.Conn.put_resp_header("location", "http://www.perdu.com")
  end
end
