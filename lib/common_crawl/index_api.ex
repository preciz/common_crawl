defmodule CommonCrawl.IndexAPI do
  @moduledoc """
  Interacting with Common Crawl index search API.
  """

  @doc """
  The `cdx_api_url` can be found in `CommonCrawl.collinfo()`.

  `"url"` parameter is required in the `query`.

  Further info: [https://github.com/webrecorder/pywb/wiki/CDX-Server-API#api-reference](https://github.com/webrecorder/pywb/wiki/CDX-Server-API#api-reference)
  """
  @receive_timeout Application.compile_env!(:common_crawl, :receive_timeout)

  @spec get(String.t(), Enum.t(), keyword) :: {:ok, list} | {:error, any}
  def get(cdx_api_url, query, opts \\ []) do
    query = URI.encode_query(query)
    url = cdx_api_url <> "?#{query}"
    opts = Keyword.put_new(opts, :receive_timeout, @receive_timeout)

    case Req.get(url, opts) do
      {:ok, %Req.Response{body: body, status: 200}} -> {:ok, parse_response(body)}
      {:ok, other} -> {:error, other}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc false
  @spec parse_response(String.t()) :: [{String.t(), integer(), map()}]
  def parse_response(response_body) when is_binary(response_body) do
    response_body
    |> String.split("\n", trim: true)
    |> Enum.map(fn line ->
      [search_key, timestamp, json] = String.split(line, " ", parts: 3)

      timestamp = String.to_integer(timestamp)
      {:ok, map} = Jason.decode(json)

      {search_key, timestamp, map}
    end)
  end
end
