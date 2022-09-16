defmodule Couloir42ReverseProxy.User do
  @enforce_keys [:username, :password]
  defstruct [:username, :password]
  @type t :: %__MODULE__{username: String.t(), password: String.t()}
end
