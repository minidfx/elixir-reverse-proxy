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
    case Passwords.find(host) do
      {:ok, %Password{encoded_password: encoded_password}} ->
        with {user, pass} <- Plug.BasicAuth.parse_basic_auth(conn),
             true <- String.equivalent?("#{user}:#{pass}" |> Base.encode64(), encoded_password) do
          user = %User{username: user, password: encoded_password}
          conn |> Conn.assign(:current_user, user)
        else
          _ ->
            conn |> Plug.BasicAuth.request_basic_auth() |> Conn.halt()
        end

      _ ->
        conn
    end
  end
end
