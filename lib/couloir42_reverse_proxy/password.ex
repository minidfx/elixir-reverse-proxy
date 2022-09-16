defmodule Couloir42ReverseProxy.Password do
  @enforce_keys [:match_domain, :encoded_password]
  defstruct [:match_domain, :encoded_password]
  @type t :: %__MODULE__{match_domain: String.t(), encoded_password: String.t()}
end
