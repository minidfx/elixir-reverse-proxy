#!/bin/sh

echo "Compiling proxy with the given upstreams ... "

mix release --no-deps-check --no-archives-check --no-elixir-version-check --overwrite --quiet

echo "Compiled, running ..."

_build/prod/rel/couloir42_reverse_proxy/bin/couloir42_reverse_proxy start