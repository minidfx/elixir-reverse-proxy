defmodule Couloir42ReverseProxy.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias Couloir42ReverseProxy.Upstreams

  @impl true
  def start(_type, _args) do
    children = [
      # Starts a worker by calling: Couloir42ReverseProxy.Worker.start_link(arg)
      # {Couloir42ReverseProxy.Worker, arg}
      Couloir42ReverseProxy.Upstreams,
      Couloir42ReverseProxy.Passwords,
      Couloir42ReverseProxy.Certbot,
      {Plug.Cowboy, scheme: :http, plug: Couloir42ReverseProxy.Router, port: 4000},
      {
        Plug.Cowboy,
        # To support multi domains for SSL termination
        scheme: :https,
        plug: Couloir42ReverseProxy.RouterSSL,
        port: 4443,
        cipher_suite: :strong,
        certfile: "priv/certs/self-signed/cert.pem",
        keyfile: "priv/certs/self-signed/key.pem",
        password: 1234,
        otp_app: :couloir42_reverse_proxy,
        sni_fun: &Upstreams.sni/1
      }
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Couloir42ReverseProxy.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
