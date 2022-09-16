defmodule Couloir42ReverseProxy.Certbot do
  use GenServer

  require Logger

  alias Couloir42ReverseProxy.Certificate
  alias Couloir42ReverseProxy.Upstreams
  alias Couloir42ReverseProxy.Upstream

  # Client

  def start_link(default) when is_list(default) do
    {:ok, pid} = GenServer.start_link(__MODULE__, default, name: :certbot)

    :ok =
      GenServer.cast(:certbot, [
        :read_certificates,
        :renew_certificates,
        :create_missing_certificates
      ])

    {:ok, pid}
  end

  @spec read_certificates :: list(Certificate.t())
  def read_certificates(), do: GenServer.call(:certbot, :read_certificates)

  # Servers (callbacks)

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_call(:read_certificates, _from, state) do
    certificates =
      case state |> Keyword.fetch(:certificates) do
        :error -> internal_read_certificates()
        {:ok, x} -> {:ok, x}
      end

    case certificates do
      :error -> {:reply, [], state}
      {:ok, x} -> {:reply, x, Keyword.put_new(state, :certificates, x)}
    end
  end

  @impl true
  def handle_cast(
        [:read_certificates, :renew_certificates, :create_missing_certificates],
        state
      ) do
    case internal_read_certificates() |> schedule_renewal() do
      :error ->
        {:noreply, state}

      {:ok, certificates} ->
        :ok = GenServer.cast(:certbot, :create_missing_certificates)
        {:noreply, Keyword.put_new(state, :certificates, certificates)}
    end
  end

  @impl true
  def handle_cast(:read_certificates, state) do
    case internal_read_certificates() do
      :error ->
        {:noreply, state}

      {:ok, certificates} ->
        {:noreply, Keyword.put_new(state, :certificates, certificates)}
    end
  end

  @impl true
  def handle_cast(:create_missing_certificates, state) do
    certificates =
      case state |> Keyword.fetch(:certificates) do
        :error -> :not_found
        {:ok, x} -> {:ok, x}
      end

    case certificates do
      :not_found ->
        {:noreply, state}

      {:ok, certificates} ->
        if create_missing_certificates(certificates, Upstreams.read()) |> Enum.any?() do
          :ok = GenServer.cast(:certbot, :read_certificates)
        end

        {:noreply, state}
    end
  end

  @impl true
  def handle_info(:renew_certificates, state) do
    case internal_read_certificates()
         |> renew_certficates()
         |> schedule_renewal() do
      :error -> {:noreply, state}
      {:ok, certificates} -> {:noreply, Keyword.put(state, :certificates, certificates)}
    end
  end

  ## Internal

  defp create_missing_certificates([], []) do
    Logger.info("No new certificates to generate.")
    []
  end

  defp create_missing_certificates([], upstreams) when is_list(upstreams) do
    Logger.info("Creating new certificates ...")

    cmd_results =
      upstreams
      |> Enum.map(fn %Upstream{match_domain: x} -> create_certficate(x) end)
      # Return only the successfull commands
      |> Enum.filter(fn {status, _} -> status == :ok end)

    Logger.info("Done.")

    cmd_results
  end

  defp create_missing_certificates(existing_certificates, upstreams) do
    Logger.info("Creating missing certificates ...")

    cmd_results =
      upstreams
      |> Enum.reject(fn %Upstream{match_domain: match_domain} ->
        existing_certificates
        |> Enum.any?(fn %Certificate{domains: domains} ->
          domains
          |> Enum.any?(fn domain ->
            domain == match_domain
          end)
        end)
      end)
      |> Enum.map(fn %Upstream{match_domain: x} -> create_certficate(x) end)

    Logger.info("Done.")

    cmd_results
  end

  defp schedule_renewal(:error), do: :error
  defp schedule_renewal({:ok, []}), do: {:ok, []}

  defp schedule_renewal({:ok, certificates}) do
    Logger.info("Scheduling the renewal for #{Enum.count(certificates)} certificates ...")

    :ok = schedule_renewal(certificates)

    {:ok, certificates}
  end

  defp schedule_renewal([]), do: :ok

  defp schedule_renewal([certificate | tail]) do
    %Certificate{expiry: expiry, name: name} = certificate

    waiting_time_in_days = Kernel.abs(Date.diff(expiry, Date.utc_today()))
    waiting_time_in_milli_seconds = waiting_time_in_days * 3600 * 24 * 1000

    Logger.info(
      "Scheduling the #{name} renewal in #{Integer.to_string(waiting_time_in_days)} days ..."
    )

    _ =
      if waiting_time_in_days == 0 do
        GenServer.cast(:certbot, :renew_certificates)
      else
        # FIXME: We have to save the previous schedules.
        Process.send_after(
          :certbot,
          :renew_certificates,
          waiting_time_in_milli_seconds
        )
      end

    schedule_renewal(tail)
  end

  defp internal_read_certificates() do
    Logger.info("Reading the certificates ...")

    cmd("certbot", ["certificates"])
    |> post_command()
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
    |> post_parsing()
  end

  defp create_certficate(hostname) do
    cmd("certbot", create_arguments_to_create_certificate(hostname))
    |> post_command(hostname)
  end

  defp renew_certficates(:error), do: :error

  defp renew_certficates({:ok, certificates}) when is_list(certificates) do
    {:ok,
     certificates
     |> Enum.map(fn %Certificate{domains: domains} = certificate ->
       _ = domains |> Enum.map(fn x -> renew_certficate(x) end)
       certificate
     end)}
  end

  defp renew_certficate(hostname) when is_bitstring(hostname) do
    cmd("certbot", create_arguments_to_renew_certificate(hostname))
    |> post_command()
  end

  defp create_arguments_to_renew_certificate(hostname) do
    args = [
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

    args =
      if is_staging?() do
        args ++ ["--staging"]
      else
        args
      end

    args
  end

  defp create_arguments_to_create_certificate(hostname) do
    args = [
      "certonly",
      "--webroot",
      "-m",
      get_email!(),
      "-d",
      hostname,
      "-w",
      "priv/static",
      "-n",
      "--agree-tos"
    ]

    args =
      if is_staging?() do
        args ++ ["--staging"]
      else
        args
      end

    args
  end

  defp post_command({text, 0}), do: {:ok, text}

  defp post_command({error, code}) do
    Logger.error("Was not able to read the certificates: #{Integer.to_string(code)}")
    Logger.error(error)

    :error
  end

  defp post_command({text, 0}, _hostname), do: {:ok, text}

  defp post_command({error, code}, hostname) do
    Logger.error(
      "Was not able to create the certificate for #{hostname}: #{Integer.to_string(code)}"
    )

    Logger.error(error)
    :error
  end

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

  defp select_first_capture_by_certificate(:error), do: :error

  defp select_first_capture_by_certificate({:ok, results}) when is_list(results) do
    {:ok,
     results
     |> Enum.map(fn certificate ->
       # By certificate
       certificate
       |> Enum.map(
         # select only the first capture
         fn captures -> Enum.at(captures, 1) end
       )
     end)}
  end

  defp group_by_certificate(:error), do: :error

  defp group_by_certificate({:ok, []}), do: {:ok, []}

  defp group_by_certificate({:ok, results}) do
    group_by =
      0..(count_properties_by_certificate(results) - 1)
      |> Enum.map(fn property_index ->
        results
        |> Enum.map(fn properties ->
          properties |> Enum.at(property_index)
        end)
      end)

    {:ok, group_by}
  end

  defp post_parsing(:error), do: :error

  defp post_parsing({:ok, results}) when is_list(results), do: post_parsing(results, [])

  defp post_parsing([], accumulator) when is_list(accumulator), do: {:ok, accumulator}

  defp post_parsing([certificate | tail], accumulator) when is_list(accumulator) do
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

    post_parsing(tail, [certificate | accumulator])
  end

  defp parse_result(:error), do: :error

  defp parse_result({:ok, text}, regexs),
    do:
      {:ok,
       regexs
       |> Enum.map(fn x -> Regex.scan(x, text) end)
       |> Enum.filter(fn x -> Enum.any?(x) end)}

  defp get_email!() do
    case System.get_env("EMAIL") |> String.downcase() do
      nil -> raise "The EMAIL was missing, cannot generate new certificate using certbot."
      x -> x
    end
  end

  defp is_staging?() do
    case System.get_env("STAGING") |> String.downcase() do
      "true" -> true
      _ -> false
    end
  end

  defp cmd(command, arguments) when is_bitstring(command) and is_list(arguments) do
    arguments_as_string = Enum.join(arguments, " ")

    Logger.debug("Executing the following command: #{command} #{arguments_as_string} ...")

    cmd_result = System.cmd(command, arguments, stderr_to_stdout: true)

    {output, code} = cmd_result

    Logger.debug("Exit code: #{code}")
    Logger.debug("Output: #{output}")

    cmd_result
  end
end
