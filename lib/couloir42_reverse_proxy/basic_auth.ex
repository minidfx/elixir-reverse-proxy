defmodule Couloir42ReverseProxy.BasicAuth do
  alias Couloir42ReverseProxy.User
  alias Couloir42ReverseProxy.Password
  alias Couloir42ReverseProxy.Passwords
  alias Plug.Conn

  require Logger

  @spec init(any) :: any
  def init(options) do
    # initialize options
    options
  end

  @spec call(Plug.Conn.t(), any) :: Plug.Conn.t()
  def call(%Conn{host: host} = conn, _opts) do
    with {:ok, %Password{encoded_password: encoded_password}} <- Passwords.find(host),
         {user, pass} <- Plug.BasicAuth.parse_basic_auth(conn),
         true <- "#{user}:#{pass}" |> Base.encode64() |> String.equivalent?(encoded_password) do
      user = %User{username: user, password: encoded_password}
      conn |> Conn.assign(:current_user, user)
    else
      :not_found ->
        conn

      _ ->
        conn |> Plug.BasicAuth.request_basic_auth() |> Conn.halt()
    end
  end
end
