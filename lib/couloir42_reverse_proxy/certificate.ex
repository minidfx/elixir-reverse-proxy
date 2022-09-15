defmodule Couloir42ReverseProxy.Certificate do
  @enforce_keys [:expiry, :serial_number, :name, :path, :key_path, :domains]
  defstruct [:expiry, :serial_number, :name, :path, :key_path, :domains]

  @type t :: %__MODULE__{
          expiry: DateTime.t(),
          serial_number: String.t(),
          name: String.t(),
          path: String.t(),
          key_path: String.t(),
          domains: list(String.t())
        }
end
