defmodule CommonCrawl do
  @moduledoc """
  Interacting with Common Crawl data.
  """

  @collinfo_json_url "https://index.commoncrawl.org/collinfo.json"
  @collinfo File.read!("priv/collinfo.json") |> Jason.decode!()

  @doc """
  Cached collinfo from disk.
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
end
