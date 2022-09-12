import Config

config :reverse_proxy_plug,
       :http_client,
       ReverseProxyPlug.HTTPClient.Adapters.HTTPoison
