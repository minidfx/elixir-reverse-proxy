import Config

config :reverse_proxy_plug,
       :http_client,
       ReverseProxyPlug.HTTPClient.Adapters.HTTPoison

config :couloir42_reverse_proxy,
       :default_ssl_opts_certfile,
       "priv/certs/self-signed/cert.pem"

config :couloir42_reverse_proxy,
       :default_ssl_opts_keyfile,
       "priv/certs/self-signed/key.pem"

config :logger, :console,
  format: "$metadata [$level] $message\n",
  metadata: [:file]

import_config "#{config_env()}.exs"
