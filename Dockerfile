FROM elixir:1.14-slim

LABEL Burgy Benjamin aka MiniDfx

COPY lib/ /app/lib/
COPY config/ /app/config/
COPY mix.exs /app/
COPY priv/ /app/priv/

EXPOSE 4000
EXPOSE 4443

WORKDIR /app

ENV MIX_ENV prod

RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get --only prod && \
    mix release

ENTRYPOINT [ "_build/prod/rel/couloir42_reverse_proxy/bin/couloir42_reverse_proxy", "start" ]