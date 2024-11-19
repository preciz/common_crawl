defmodule CommonCrawl.WARC do
  @moduledoc """
  Common Crawl .warc file download and parsing
  """
  @s3_base_url Application.compile_env!(:common_crawl, :s3_base_url)
  @receive_timeout Application.compile_env!(:common_crawl, :receive_timeout)

  @doc """
  Fetches a segment of the WARC file.
  """
  @spec get_segment(String.t(), integer(), integer(), keyword()) ::
          {:ok, %{warc: String.t(), headers: String.t(), response: String.t()}} | {:error, any()}
  def get_segment(filename, offset, length, opts \\ []) when is_binary(filename) and is_integer(offset) and is_integer(length) and length > 0 do
    url = @s3_base_url <> filename

    headers =
      Enum.concat(opts[:headers] || [], [{"Range", "bytes=#{offset}-#{offset + length - 1}"}])

    opts =
      opts
      |> Keyword.put(:headers, headers)
      |> Keyword.put_new(:receive_timeout, @receive_timeout)

    case Req.get(url, opts) do
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
  defp parse_response_body(bin) do
    bin
    |> String.trim()
    |> String.split("\r\n\r\n", parts: 3)
  end
end
