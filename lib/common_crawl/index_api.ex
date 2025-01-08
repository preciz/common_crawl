defmodule CommonCrawl.IndexAPI do
  @moduledoc """
  Interacting with Common Crawl index search API.
  """

  @doc """
  Searches the Common Crawl CDX API for entries matching the given query parameters.

  The `cdx_api_url` can be found in `CommonCrawl.collinfo()`.
  The `"url"` parameter is required in the `query` map.

  ## Parameters
    * `cdx_api_url` - The CDX API endpoint URL for a specific crawl
    * `query` - Map of query parameters (url is required)
    * `opts` - Request options passed to Req.get/2

  ## Examples

      # Search for a specific URL in a crawl
      cdx_api_url = "https://index.commoncrawl.org/CC-MAIN-2023-50-index"
      {:ok, entries} = CommonCrawl.IndexAPI.get(cdx_api_url, %{"url" => "https://example.com"})

      # Search with additional filters
      {:ok, entries} = CommonCrawl.IndexAPI.get(
        cdx_api_url,
        %{
          "url" => "https://example.com",
          "filter" => "statuscode:200",
          "limit" => "1"
        }
      )

  Further info: [https://github.com/webrecorder/pywb/wiki/CDX-Server-API#api-reference](https://github.com/webrecorder/pywb/wiki/CDX-Server-API#api-reference)
  """
  @receive_timeout Application.compile_env(:common_crawl, :receive_timeout, 120_000)

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

  @doc """
  Searches for the latest available version of a URL across recent crawls.
  Returns the most recent entry if found, nil otherwise.

  ## Examples

      # Search in default 4 most recent crawls
      get_latest_for_url("https://example.com")

      # Search in 6 most recent crawls
      get_latest_for_url("https://example.com", crawls_to_check: 6)

  ## Return Value

      {"com,example)/", 20241214183829,
       %{
         "digest" => "JI6OR3QR4CI526JD6TMMNZNV4QPMPQCH",
         "encoding" => "UTF-8",
         "filename" => "crawl-data/CC-MAIN-2024-51/segments/1733066125982.36/warc/CC-MAIN-20241214181735-20241214211735-00433.warc.gz",
         "languages" => "eng",
         "length" => "1223",
         "mime" => "text/html",
         "mime-detected" => "text/html",
         "offset" => "36544657",
         "status" => "200",
         "url" => "http://www.example.com"
       }}
  """
  @spec get_latest_for_url(String.t(), keyword()) :: {String.t(), non_neg_integer(), map()} | nil
  def get_latest_for_url(url, opts \\ []) do
    crawls_to_check = Keyword.get(opts, :crawls_to_check, 4)

    CommonCrawl.collinfo()
    |> Enum.take(crawls_to_check)
    |> Enum.find_value(fn %{"cdx-api" => cdx_api_url} ->
      case get(cdx_api_url, %{"url" => url}, opts) do
        {:ok, [_ | _] = entries} ->
          entries
          |> Enum.sort_by(fn {_, timestamp, _} -> timestamp end, :desc)
          |> hd()

        _ ->
          false
      end
    end)
  end

  @doc false
  @spec parse_response(String.t()) :: [{String.t(), integer(), map()}]
  def parse_response(response_body) when is_binary(response_body) do
    response_body
    |> String.split("\n", trim: true)
    |> Enum.map(fn line ->
      [search_key, timestamp, json] = String.split(line, " ", parts: 3)

      timestamp = String.to_integer(timestamp)
      {:ok, map} = JSON.decode(json)

      {search_key, timestamp, map}
    end)
  end
end
