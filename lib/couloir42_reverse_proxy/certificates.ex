defmodule Couloir42ReverseProxy.Certificates do
  alias Couloir42ReverseProxy.Certificate

  @spec read :: {:ok, [Couloir42ReverseProxy.Certificate.t()]} | {:error, String.t()}
  def read() do
    case System.cmd("certbot", ["certificates"], stderr_to_stdout: true) do
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

  defp parse_result(text, regexs),
    do:
      regexs
      |> Enum.map(fn x -> Regex.scan(x, text) end)
      |> Enum.filter(fn x -> Enum.any?(x) end)

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
end
