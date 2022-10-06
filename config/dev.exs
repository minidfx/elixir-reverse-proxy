import Config

config :logger, :console, level: :debug

config :couloir42_reverse_proxy,
       :default_ssl_opts_certfile,
       "priv/certs/self-signed/cert.pem"

config :couloir42_reverse_proxy,
       :default_ssl_opts_keyfile,
       "priv/certs/self-signed/key.pem"
