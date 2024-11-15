defmodule CommonCrawl.WARC do
  @moduledoc """
  Common Crawl .warc file download and parsing
  """
  @s3_base_url Application.compile_env!(:common_crawl, :s3_base_url)

  @httpoison_options [
    default_timeout: :timer.minutes(2),
    recv_timeout: :timer.minutes(2)
  ]

  @doc """
  Fetches a segment of the WARC file.
  """
  def get_segment(filename, offset, length, headers \\ [], options \\ [])
      when is_binary(filename) and is_integer(offset) and is_integer(length) do
    url = @s3_base_url <> filename
    options = Keyword.merge(@httpoison_options, options)
    headers = headers ++ [{"Range", "bytes=#{offset}-#{offset + length - 1}"}]

    case HTTPoison.get(url, headers, options) do
      {:ok, %{body: body}} ->
        case parse_response_body(body) do
          [warc, headers, response] ->
            {:ok, %{warc: warc, headers: headers, response: response}}

          other ->
            {:error, {:no_headers_or_response, other}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec parse_response_body(binary()) :: [String.t()]
  defp parse_response_body(gzipped_bin) do
    gzipped_bin
    |> :zlib.gunzip()
    |> String.trim()
    |> String.split("\r\n\r\n", parts: 3)
  end
end
