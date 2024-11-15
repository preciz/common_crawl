defmodule CommonCrawl do
  @moduledoc """
  CommonCrawl library helps to interact with Common Crawl data.
  """

  @collinfo_json_url "https://index.commoncrawl.org/collinfo.json"
  @collinfo File.read!("priv/collinfo.json") |> Jason.decode!()

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
  def get_collinfo(headers \\ [], options \\ []) do
    case HTTPoison.get(@collinfo_json_url, headers, options) do
      {:ok, %HTTPoison.Response{body: body}} -> Jason.decode(body)
      {:error, error} -> {:error, error}
    end
  end

  @doc false
  def update_collinfo!() do
    {:ok, collinfo} = get_collinfo()
    json_string = collinfo |> Jason.encode!(pretty: true)

    File.write!("priv/collinfo.json", json_string)
  end
end
