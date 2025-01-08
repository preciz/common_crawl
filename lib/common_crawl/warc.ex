defmodule CommonCrawl.WARC do
  @moduledoc """
  Common Crawl .warc file download and parsing
  """
  @base_url Application.compile_env(:common_crawl, :base_url, "https://data.commoncrawl.org/")
  @receive_timeout Application.compile_env(:common_crawl, :receive_timeout, 120_000)

  @doc """
  Fetches a segment of the WARC file.

  ## Examples

      iex> CommonCrawl.WARC.get_segment(
      ...>   "crawl-data/CC-MAIN-2024-51/segments/1733066125982.36/warc/CC-MAIN-20241214181735-20241214211735-00433.warc.gz",
      ...>   36544657,
      ...>   1223
      ...> )

  ## Return Value

      {:ok,
       %{
         warc: "WARC/1.0\\r\\nWARC-Type: response\\r\\nWARC-Date: 2024...",
         headers: "HTTP/1.1 200 OK\\r\\nContent-Type: text/html...", 
         response: "&lt;!doctype html&gt;\\n&lt;html&gt;\\n&lt;head&gt;\\n&lt;title&gt;Example..."
       }}
  """
  @spec get_segment(String.t(), integer(), integer(), keyword()) ::
          {:ok, %{warc: String.t(), headers: String.t(), response: String.t()}} | {:error, any()}
  def get_segment(filename, offset, length, opts \\ [])
      when is_binary(filename) and is_integer(offset) and is_integer(length) and length > 0 do
    uri = URI.merge(@base_url, filename)

    headers =
      Enum.concat(opts[:headers] || [], [{"Range", "bytes=#{offset}-#{offset + length - 1}"}])

    opts =
      opts
      |> Keyword.put(:headers, headers)
      |> Keyword.put_new(:receive_timeout, @receive_timeout)

    case Req.get(uri, opts) do
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
