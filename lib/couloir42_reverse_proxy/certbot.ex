defmodule Couloir42ReverseProxy.Certbot do
  use GenServer

  require Logger

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
    with {:ok, certificates} <- internal_read_certificates(),
         {:ok, _commands} = renew_certificates(certificates),
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
        :error -> internal_read_certificates()
        {:ok, x} -> {:ok, x}
      end

    case certificates do
      {:error, reason} -> {:reply, {:error, reason}, state}
      {:ok, x} -> {:reply, x, Keyword.put_new(state, :certificates, x)}
    end
  end

  @impl true
  def handle_cast([:read_certificates, :schedule_renewal_certificates], state) do
    with {:ok, certificates} <- internal_read_certificates(),
         :ok <- schedule_renewal(certificates),
         {:ok, new_certificates} <- internal_read_certificates() do
      {:noreply, Keyword.put(state, :certificates, new_certificates)}
    else
      _ -> {:noreply, state}
    end
  end

  @impl true
  def handle_cast(:read_certificates, state) do
    case internal_read_certificates() do
      {:ok, certificates} -> {:noreply, Keyword.put(state, :certificates, certificates)}
      {:error, reason} -> {:stop, reason, state}
    end
  end

  @impl true
  def handle_info(:renew_certificates, state) do
    with {:ok, certificates} <- internal_read_certificates(),
         {:ok, _results} <- renew_certificates(certificates) do
      _ = certificates |> schedule_renewal()
      {:noreply, Keyword.put(state, :certificates, certificates)}
    else
      {:warning, results} when is_list(results) ->
        results
        |> Enum.filter(&match?({:warning, _, _}, &1))
        |> Enum.each(fn {:warning, reason, certificate} ->
          _ =
            certificate
            |> schedule_renewal()

          Logger.warn(reason)
        end)

        {:noreply, state}

      {:error, reason} when is_bitstring(reason) ->
        {:stop, reason, state}
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

  defp schedule_renewal(results) when is_list(results) do
    results
    |> Enum.filter(&match?({:ok, _, _}, &1))
    |> Enum.map(fn {:ok, _, x} -> x end)
    |> Enum.each(&schedule_renewal/1)
  end

  defp schedule_renewal(%Certificate{} = certificate) do
    {_, waiting_time_in_days} = is_expired(certificate)
    waiting_time_in_milli_seconds = waiting_time_in_days * 3600 * 24 * 1000
    %Certificate{name: name} = certificate

    _ =
      if waiting_time_in_days == 0 do
        Logger.info("Renewing the certificate #{name} ...")
        GenServer.cast(:certbot, :renew_certificates)
      else
        Logger.info("Scheduling renewal of the cerfificate #{name} in #{waiting_time_in_days} days ...")

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

  defp internal_read_certificates() do
    case cmd("certbot", ["certificates"]) do
      {text, 0} ->
        certificates =
          text
          |> parse_result([
            ~r/Certificate Name: ([^\n]*)/,
            ~r/Domains: ([^\n]*)/,
            ~r/Expiry Date: (\d{4}-\d{2}-\d{2})/,
            ~r/Certificate Path: ([^\n]*)/,
            ~r/Private Key Path: ([^\n]*)/,
            ~r/Serial Number: ([^\n]*)/
          ])
          |> group_by_certificate()
          |> select_first_capture_by_certificate()
          |> certificates_factory()

        {:ok, certificates}

      {error, code} ->
        {:error, "Was not able to read the certificate: #{Integer.to_string(code)}, #{error}"}
    end
  end

  defp create_certificate(hostname) when is_bitstring(hostname) do
    case cmd("certbot", create_arguments_to_create_certificate(hostname)) do
      {text, 0} ->
        {:ok, text}

      {error, code} ->
        {:error, "Was not able to create the certificate for #{hostname}: #{Integer.to_string(code)}, #{error}"}
    end
  end

  defp renew_certificates([]), do: {:ok, []}

  defp renew_certificates(certificates) when is_list(certificates) do
    results =
      certificates
      |> Enum.map(&is_expired/1)
      |> Enum.filter(&match?({:expired, _}, &1))
      |> Enum.map(fn certificate ->
        %Certificate{domains: domains} = certificate

        domains
        |> Enum.map(fn x -> renew_certificate(x) end)
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

  defp renew_certificate(hostname) when is_bitstring(hostname) do
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
        "--agree-tos",
        "-q"
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

  defp count_properties_by_certificate(results) when is_list(results) do
    # [
    #   [
    #     ["Certificate Name: couloir42.internet-box.ch", "couloir42.internet-box.ch"],
    #     ["Certificate Name: couloir42.internet-box.ch", "couloir42.internet-box.ch"]
    #   ],
    #   [
    #     ["Domains: couloir42.internet-box.ch", "couloir42.internet-box.ch"],
    #     ["Domains: couloir42.internet-box.ch", "couloir42.internet-box.ch"]
    #   ],
    #   [
    #     ["Expiry Date: 2022-12-12", "2022-12-12"],
    #     ["Expiry Date: 2022-12-13", "2022-12-13"]
    #   ],
    #   [
    #     ["Certificate Path: /etc/letsencrypt/live/couloir42.internet-box.ch/fullchain.pem", "/etc/letsencrypt/live/couloir42.internet-box.ch/fullchain.pem"],
    #     ["Certificate Path: /etc/letsencrypt/live/couloir42.internet-box.ch/fullchain.pem", "/etc/letsencrypt/live/couloir42.internet-box.ch/fullchain.pem"]
    #   ],
    #   [
    #     ["Serial Number: fa2157e6a5ff25a2ad11b600c7b5dcc677d8", "fa2157e6a5ff25a2ad11b600c7b5dcc677d8"],
    #     ["Serial Number: fa2157e6a5ff25a2ad11b600c7b5dcc677d8", "fa2157e6a5ff25a2ad11b600c7b5dcc677d8"]
    #   ]
    # ]
    results
    # Take the first level
    |> List.first([])
    # Count the first level
    |> Enum.count()
  end

  defp select_first_capture_by_certificate([]), do: []

  defp select_first_capture_by_certificate(results) when is_list(results) do
    results
    |> Enum.map(fn certificate ->
      # By certificate
      certificate
      |> Enum.map(
        # select only the first capture
        fn captures -> Enum.at(captures, 1) end
      )
    end)
  end

  defp group_by_certificate([]), do: []

  defp group_by_certificate(captures) do
    0..(count_properties_by_certificate(captures) - 1)
    |> Enum.map(fn property_index ->
      captures
      |> Enum.map(fn properties ->
        properties |> Enum.at(property_index)
      end)
    end)
  end

  defp certificates_factory(results) when is_list(results), do: certificate_factory(results, [])

  defp certificate_factory([], accumulator) when is_list(accumulator), do: accumulator

  defp certificate_factory([certificate | tail], accumulator) when is_list(accumulator) do
    certificate_name = certificate |> Enum.at(0)
    domains = certificate |> Enum.at(1) |> String.split(",", trim: true)
    expiry_date = Date.from_iso8601!(certificate |> Enum.at(2))
    certificate_path = certificate |> Enum.at(3)
    private_key_path = certificate |> Enum.at(4)
    serial_number = certificate |> Enum.at(5)

    certificate = %Certificate{
      name: certificate_name,
      domains: domains,
      expiry: expiry_date,
      path: certificate_path,
      key_path: private_key_path,
      serial_number: serial_number
    }

    certificate_factory(tail, [certificate | accumulator])
  end

  defp parse_result(text, regexs),
    do:
      regexs
      |> Enum.map(fn x -> Regex.scan(x, text) end)
      |> Enum.filter(fn x -> Enum.any?(x) end)

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
