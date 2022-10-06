import Config

config :reverse_proxy_plug,
       :http_client,
       ReverseProxyPlug.HTTPClient.Adapters.HTTPoison

config :logger, :console,
  format: "$metadata [$level] $message\n",
  metadata: [:file]

import_config "#{config_env()}.exs"
