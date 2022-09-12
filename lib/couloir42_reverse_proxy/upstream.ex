defmodule Couloir42ReverseProxy.Upstream do
  @enforce_keys [:match_domain, :upstream]
  defstruct [:match_domain, :upstream]
  @type t :: %__MODULE__{match_domain: String.t(), upstream: URI.t()}
end
