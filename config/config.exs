import Config

config :couloir42_reverse_proxy,
       :upstreams,
       %{
         "foobar.localhost" => "http://example.com"
       }

config :reverse_proxy_plug,
       :http_client,
       ReverseProxyPlug.HTTPClient.Adapters.HTTPoison
