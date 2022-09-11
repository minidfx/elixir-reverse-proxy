FROM elixir:1.14-slim

LABEL Burgy Benjamin aka MiniDfx

COPY lib/ /app/lib/
COPY config/ /app/config/
COPY mix.exs /app/

WORKDIR /app

ENV MIX_ENV prod

RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get --only prod && \
    mix compile

ENTRYPOINT [ "mix", "run", "--no-halt" ]