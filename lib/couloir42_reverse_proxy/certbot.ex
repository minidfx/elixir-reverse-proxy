defmodule Couloir42ReverseProxy.Certbot do
  use GenServer

  require Logger

  alias Couloir42ReverseProxy.Certificates
  alias Couloir42ReverseProxy.Certificate
  alias Couloir42ReverseProxy.Upstreams
  alias Couloir42ReverseProxy.Upstream

  # Client

  def start_link(default) when is_list(default) do
    {:ok, pid} = GenServer.start_link(__MODULE__, default, name: :certbot)

    :ok = GenServer.cast(pid, [:read_certificates, :schedule_renewal_certificates])

    {:ok, pid}
  end

  @spec read_certificates :: list(Certificate.t())
  def read_certificates(), do: GenServer.call(:certbot, :read_certificates)

  @spec refresh() ::
          :ok
          | {:warning, String.t(), list({atom(), String.t(), Certificate.t()})}
          | {:error, String.t()}
          | {:error, String.t(), list({atom(), String.t()})}
  def refresh() do
    with {:ok, certificates} <- Certificates.read(),
         {:ok, _commands} = internal_renew_certificates(certificates),
         upstreams <- Upstreams.compiled_read(persist: false),
         {:ok, _commands} <- create_missing_certificates(certificates, upstreams) do
      :ok
    else
      {:warning, results} when is_list(results) -> {:warning, "Some commands are invalid, check the inner results.", results}
      {:error, reason, results} when is_list(results) -> {:error, reason, results}
      {:error, reason} when is_bitstring(reason) -> {:error, reason}
    end
  end

  # Servers (callbacks)

  @impl true
  def init(state),
    do: {:ok, state}

  @impl true
  def handle_call(:read_certificates, _from, state) do
    certificates =
      case state |> Keyword.fetch(:certificates) do
        :error -> Certificates.read()
        {:ok, x} -> {:ok, x}
      end

    case certificates do
      {:error, reason} -> {:reply, {:error, reason}, state}
      {:ok, x} -> {:reply, x, Keyword.put_new(state, :certificates, x)}
    end
  end

  @impl true
  def handle_info(:renew_certificates, state) do
    with {:ok, certificates} <- Certificates.read(),
         {:ok, _} <- internal_renew_certificates(certificates),
         :ok <- certificates |> schedule_renewal() do
      _ = Logger.info("Certificated renewed.")
      {:noreply, Keyword.put(state, :certificates, certificates)}
    else
      {:warning, results} when is_list(results) ->
        results
        |> Enum.filter(&match?({:warning, _, _}, &1))
        |> Enum.each(fn {:warning, reason, certificate} ->
          _ =
            certificate
            |> schedule_renewal()

          _ = Logger.warn(reason)
        end)

        {:noreply, state}

      {:error, reason} when is_bitstring(reason) ->
        {:stop, reason, state}
    end
  end

  @impl true
  def handle_cast([:read_certificates, :schedule_renewal_certificates], state) do
    with {:ok, certificates} <- Certificates.read(),
         :ok <- schedule_renewal(certificates),
         {:ok, new_certificates} <- Certificates.read() do
      {:noreply, Keyword.put(state, :certificates, new_certificates)}
    else
      {:error, reason} ->
        Logger.error(reason)
        {:noreply, state}

      x ->
        Logger.error("An unknown error occurred: #{inspect(x)}")
        {:noreply, state}
    end
  end

  @impl true
  def handle_cast(:read_certificates, state) do
    case Certificates.read() do
      {:ok, certificates} -> {:noreply, Keyword.put(state, :certificates, certificates)}
      {:error, reason} -> {:stop, reason, state}
    end
  end

  ## Internal

  defp create_missing_certificates([], []), do: {:ok, []}

  defp create_missing_certificates([], upstreams) when is_list(upstreams) do
    results =
      upstreams
      |> Enum.map(fn %Upstream{match_domain: x} -> create_certificate(x) end)

    error_results = results |> Enum.filter(&match?({:error, _}, &1))

    if error_results |> Enum.any?() do
      {:error, "Was not able to create some missing certificates, please check inner errors.", error_results}
    else
      {:ok, results}
    end
  end

  defp create_missing_certificates(existing_certificates, upstreams) do
    results =
      upstreams
      |> Enum.reject(fn %Upstream{match_domain: match_domain} ->
        existing_certificates
        |> Enum.map(fn %Certificate{domains: domains} ->
          domains
          |> Enum.any?(fn domain -> domain == match_domain end)
        end)
        |> Enum.reduce([], fn x, acc -> [x | acc] end)
        |> Enum.any?(fn x -> x end)
      end)
      |> Enum.map(fn %Upstream{match_domain: x} -> create_certificate(x) end)

    error_results = results |> Enum.filter(&match?({:error, _}, &1))

    if error_results |> Enum.any?() do
      {:error, "Was not able to create some missing certificates, please check inner errors.", error_results}
    else
      {:ok, results}
    end
  end

  defp schedule_renewal([]), do: :ok

  defp schedule_renewal(results) when is_list(results),
    do:
      results
      |> Enum.each(&schedule_renewal/1)

  defp schedule_renewal(%Certificate{} = certificate) do
    {_, waiting_time_in_days} = is_expired(certificate)
    # waiting_time_in_milli_seconds = waiting_time_in_days * 3600 * 24 * 1000
    waiting_time_in_milli_seconds = 1 * 5000
    %Certificate{name: name} = certificate

    _ =
      if waiting_time_in_days == 0 do
        Logger.info("Renewing the certificate #{name} ...")
        _ = GenServer.call(:certbot, :renew_certificates)
      else
        Logger.info("The cerfificate #{name} will be renewed in #{waiting_time_in_days} days ...")

        # FIXME: We have to save the previous schedules.
        _ =
          Process.send_after(
            :certbot,
            :renew_certificates,
            waiting_time_in_milli_seconds
          )
      end

    :ok
  end

  defp create_certificate(hostname) when is_bitstring(hostname) do
    case cmd("certbot", create_arguments_to_create_certificate(hostname)) do
      {text, 0} ->
        {:ok, text}

      {error, code} ->
        {:error, "Was not able to create the certificate for #{hostname}: #{Integer.to_string(code)}, #{error}"}
    end
  end

  defp internal_renew_certificates([]), do: {:ok, []}

  defp internal_renew_certificates(certificates) when is_list(certificates) do
    results =
      certificates
      |> Enum.map(&is_expired/1)
      |> Enum.filter(&match?({:expired, _}, &1))
      |> Enum.map(fn certificate ->
        %Certificate{domains: domains} = certificate

        domains
        |> Enum.map(fn x -> internal_renew_certificate(x) end)
        |> Enum.map(fn x ->
          case x do
            {:ok, text} -> {:ok, text, certificate}
            {:warning, reason} -> {:warning, reason, certificate}
          end
        end)
      end)
      |> Enum.reduce([], fn x, acc -> x ++ acc end)

    warning_results = results |> Enum.filter(&match?({:warning, _, _}, &1))

    if warning_results |> Enum.any?() do
      {:warning, warning_results}
    else
      {:ok, results}
    end
  end

  defp internal_renew_certificate(hostname) when is_bitstring(hostname) do
    case cmd("certbot", create_arguments_to_renew_certificate(hostname)) do
      {text, 0} ->
        {:ok, text}

      {error, code} ->
        {:error, "Was not able to renew the certificate for #{hostname}: #{Integer.to_string(code)}, #{error}"}
    end
  end

  defp create_arguments_to_renew_certificate(hostname),
    do:
      [
        "renew",
        "--webroot",
        "-w",
        "priv/static",
        "--cert-name",
        hostname,
        "-n",
        "--agree-tos"
      ]
      |> append("--staging", &is_staging?/0)

  defp create_arguments_to_create_certificate(hostname),
    do:
      [
        "certonly",
        "--standalone",
        "-m",
        get_email!(),
        "-d",
        hostname,
        "-n",
        "--agree-tos"
      ]
      |> append("--staging", &is_staging?/0)

  defp get_email!() do
    case System.get_env("EMAIL") do
      nil -> raise "The EMAIL was missing, cannot generate new certificate using certbot."
      x -> x |> String.downcase()
    end
  end

  defp is_staging?() do
    case System.get_env("STAGING", "false") |> String.downcase() do
      "true" -> true
      _ -> false
    end
  end

  defp is_expired(%Certificate{expiry: expiry}) do
    expiration_days = Kernel.abs(Date.diff(expiry, Date.utc_today()))

    if expiration_days < 1 do
      {:expired, expiration_days}
    else
      {:ok, expiration_days}
    end
  end

  defp cmd(command, arguments) when is_bitstring(command) and is_list(arguments),
    do: System.cmd(command, arguments, stderr_to_stdout: true)

  defp append(list, item, predicate)
       when is_function(predicate) and is_list(list),
       do: if(predicate.(), do: list ++ [item], else: list)
end
