defmodule Couloir42ReverseProxyTest do
  use ExUnit.Case
  doctest Couloir42ReverseProxy

  test "greets the world" do
    assert Couloir42ReverseProxy.hello() == :world
  end
end
