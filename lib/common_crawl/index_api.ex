defmodule CommonCrawl.IndexAPI do
  @moduledoc """
  Interacting with Common Crawl index search API.
  """

  @httpoison_options [
    default_timeout: :timer.minutes(2),
    recv_timeout: :timer.minutes(2)
  ]

  @doc """
  The `cdx_api_url` can be found in `CommonCrawl.collinfo()`.

  `"url"` parameter is required in the `query`.

  Further info: [https://github.com/webrecorder/pywb/wiki/CDX-Server-API#api-reference](https://github.com/webrecorder/pywb/wiki/CDX-Server-API#api-reference)
  """
  @spec get(String.t(), Enum.t(), keyword, keyword) :: {:ok, list} | {:error, any}
  def get(cdx_api_url, query, headers \\ [], options \\ []) do
    query = URI.encode_query(query)
    url = cdx_api_url <> "?#{query}"
    options = Keyword.merge(@httpoison_options, options)

    case HTTPoison.get(url, headers, options) do
      {:ok, %HTTPoison.Response{body: body, status_code: 200}} -> {:ok, parse_response(body)}
      {:ok, other} -> {:error, other}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc false
  def parse_response(response_body) do
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
