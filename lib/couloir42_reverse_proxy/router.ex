defmodule Couloir42ReverseProxy.Router do
  use Plug.Router

  plug(Plug.Logger)

  plug(Plug.Static, from: "priv/static/.well-known", at: "/.well-known")

  plug(:match)
  plug(:dispatch)

  match _ do
    send_resp(conn, 404, "oops")
  end
end
