defmodule UpstreamsTest do
  use ExUnit.Case, async: false

  import Mock

  alias Couloir42ReverseProxy.Certbot
  alias Couloir42ReverseProxy.KeyValueParser
  alias Couloir42ReverseProxy.Upstreams
  alias Couloir42ReverseProxy.Upstream
  alias Couloir42ReverseProxy.Certificate

  test_with_mock "no upstreams specified.", KeyValueParser, read: fn _name, _factory -> [] end do
    assert Upstreams.compiled_read(persist: false) == []
  end

  test "not found the upstream and get the default certificate." do
    with_mocks([
      {Agent, [], [get_and_update: fn _m, _fn -> %{} end]},
      {Application, [],
       [
         get_env: fn _app, key ->
           case key do
             :default_ssl_opts_certfile -> "certificate file path"
             :default_ssl_opts_keyfile -> "key file path"
           end
         end
       ]}
    ]) do
      assert Upstreams.sni("an hostname") == [
               certfile: "certificate file path",
               keyfile: "key file path"
             ]
    end
  end

  test "found the upstream with its valid certificate." do
    with_mocks([
      {Agent, [],
       [
         get_and_update: fn _m, _fn ->
           %{
             "domain.com" => %Upstream{
               match_domain: "domain.com",
               upstream: URI.new!("http://localhost.local")
             }
           }
         end
       ]},
      {Certbot, [],
       [
         read_certificates: fn ->
           [
             %Certificate{
               domains: ["domain.com"],
               serial_number: "1234",
               key_path: "a key path",
               path: "a cert path",
               name: "a name",
               expiry: DateTime.utc_now()
             }
           ]
         end
       ]}
    ]) do
      assert Upstreams.sni("domain.com") == [certfile: "a cert path", keyfile: "a key path"]
    end
  end

  test "not found the upstream because the certificate doesn't exist" do
    with_mocks([
      {Agent, [],
       [
         get_and_update: fn _m, _fn ->
           %{
             "domain.com" => %Upstream{
               match_domain: "domain.com",
               upstream: URI.new!("http://localhost.local")
             }
           }
         end
       ]},
      {Application, [],
       [
         get_env: fn _app, key ->
           case key do
             :default_ssl_opts_certfile -> "default certificate file path"
             :default_ssl_opts_keyfile -> "default key file path"
           end
         end
       ]},
      {Certbot, [],
       [
         read_certificates: fn ->
           [
             %Certificate{
               domains: ["another-domain.com"],
               serial_number: "1234",
               key_path: "a key path",
               path: "a cert path",
               name: "a name",
               expiry: DateTime.utc_now()
             }
           ]
         end
       ]}
    ]) do
      assert Upstreams.sni("domain.com") == [certfile: "default certificate file path", keyfile: "default key file path"]
    end
  end

  test "found the upstream because the requested domain match one of the available certificate domains." do
    with_mocks([
      {Agent, [],
       [
         get_and_update: fn _m, _fn ->
           %{
             "domain.com" => %Upstream{
               match_domain: "domain.com",
               upstream: URI.new!("http://localhost.local")
             }
           }
         end
       ]},
      {Certbot, [],
       [
         read_certificates: fn ->
           [
             %Certificate{
               domains: ["another-domain.com", "another-domain-2.com", "domain.com"],
               serial_number: "1234",
               key_path: "a key path",
               path: "a cert path",
               name: "a name",
               expiry: DateTime.utc_now()
             }
           ]
         end
       ]}
    ]) do
      assert Upstreams.sni("domain.com") == [certfile: "a cert path", keyfile: "a key path"]
    end
  end
end
