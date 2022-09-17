#!/bin/sh

echo "Compiling proxy with the given upstreams ... ${UPSTREAMS} "

mix release --no-deps-check --no-archives-check --no-elixir-version-check --overwrite --quiet

echo "Compiled."

# Checking missing certificates ...
mix certbot

echo "Running ..."

_build/prod/rel/couloir42_reverse_proxy/bin/couloir42_reverse_proxy start