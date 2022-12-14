defmodule KeyValueParserTest do
  use ExUnit.Case, async: false

  import Mock

  alias Couloir42ReverseProxy.KeyValueParser

  test "read only invalid valid keys values." do
    with_mock(System, get_env: fn _name -> "something" end) do
      assert KeyValueParser.read("a variable name", fn _ -> {:ok, %{}} end) == []
    end
  end

  test "read values with the = separator at the end, like often base64" do
    with_mock(System, get_env: fn _name -> "key1=value1==,key2=value2=" end) do
      assert KeyValueParser.read("a variable name", fn {k, v} -> {:ok, {k, v}} end) == [{"key1", "value1=="}, {"key2", "value2="}]
    end
  end

  test "read valid key values and skip bad values." do
    with_mock(System, get_env: fn _name -> "key=value,fdsfdsmk;fds,prizt=fedsfd" end) do
      assert KeyValueParser.read("a variable name", fn {k, v} -> {:ok, {k, v}} end) == [{"key", "value"}, {"prizt", "fedsfd"}]
    end
  end

  test "read valid key values and skip bad values containing equals separator." do
    with_mock(System, get_env: fn _name -> "key=value,prizt=fed=sfd" end) do
      assert KeyValueParser.read("a variable name", fn {k, v} -> {:ok, {k, v}} end) == [{"key", "value"}, {"prizt", "fed=sfd"}]
    end
  end
end
