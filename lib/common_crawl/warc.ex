defmodule CommonCrawl.WARC do
  @moduledoc """
  Common Crawl .warc file download and parsing
  """
  @s3_base_url "https://commoncrawl.s3.amazonaws.com/"

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
        [warc, headers, response] =
          :zlib.gunzip(body)
          |> String.trim()
          |> String.split("\r\n\r\n", parts: 3)

        {:ok, %{warc: warc, headers: headers, response: response}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
