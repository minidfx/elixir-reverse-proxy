FROM elixir:1.14-alpine

LABEL Burgy Benjamin aka MiniDfx

COPY entrypoint.sh /app/
COPY lib/ /app/lib/
COPY config/ /app/config/
COPY mix.exs /app/
COPY priv/ /app/priv/

EXPOSE 4000
EXPOSE 4443

WORKDIR /app

ENV MIX_ENV prod

RUN apk add --update python3 py3-pip && \
    apk add certbot

RUN chmod +x entrypoint.sh && \
    mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get --only prod && \
    mix deps.compile --force

ENTRYPOINT [ "./entrypoint.sh" ]