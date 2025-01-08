defmodule CommonCrawl do
  @moduledoc """
  CommonCrawl library helps to interact with Common Crawl data.
  """

  alias CommonCrawl.{IndexAPI, WARC}

  @doc """
  Fetches the latest available crawl data for a given URL.

  ## Examples

      iex> CommonCrawl.get_latest_for_url("https://example.com")
      {:ok,
       %{
         warc: "WARC/1.0\r\nWARC-Type: response\r\nWARC-Date: 2024-01-14...",
         headers: "HTTP/1.1 200 OK\r\nContent-Type: text/html...",
         response: "<!doctype html>\n<html>\n<head>\n<title>Example Domain</title>..."
       }}
  """
  @spec get_latest_for_url(String.t(), keyword()) :: {:ok, map()} | {:error, any()}
  def get_latest_for_url(url, opts \\ []) when is_binary(url) do
    case IndexAPI.get_latest_for_url(url, opts) do
      {_search_key, _timestamp, map} ->
        with {offset, ""} <- Integer.parse(map["offset"]),
             {length, ""} <- Integer.parse(map["length"]) do
          WARC.get_segment(map["filename"], offset, length, opts)
        end

      nil ->
        {:error, :not_found}
    end
  end

  @collinfo_json_url "https://index.commoncrawl.org/collinfo.json"
  @collinfo File.read!("priv/collinfo.json") |> JSON.decode!()

  @doc """
  Cached collinfo from disk.

  ## Examples

      CommonCrawl.collinfo()
      [%{
        "cdx-api" => "https://index.commoncrawl.org/CC-MAIN-2021-43-index",
        "id" => "CC-MAIN-2021-43",
        "name" => "October 2021 Index",
        "timegate" => "https://index.commoncrawl.org/CC-MAIN-2021-43/"
      }, ...]

  """
  @spec collinfo :: [map]
  def collinfo, do: @collinfo

  @doc """
  Fetches current collinfo with all available crawls.
  """
  @spec get_collinfo() :: {:ok, [map]} | {:error, any}
  def get_collinfo(opts \\ []) do
    case Req.get(@collinfo_json_url, opts) do
      {:ok, %Req.Response{body: body}} -> {:ok, body}
      {:error, error} -> {:error, error}
    end
  end

  @doc false
  def update_collinfo!() do
    {:ok, collinfo} = get_collinfo()
    json_string = collinfo |> JSON.encode!()

    File.write!("priv/collinfo.json", json_string)
  end
end
