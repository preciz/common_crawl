defmodule CommonCrawl.Index do
  @moduledoc """
  Interacting with index files of Common Crawl.
  """

  @s3_base_url Application.compile_env!(:common_crawl, :s3_base_url)

  @doc """
  Fetches all available index files for a given crawl.
  At the end of the list will be the "metadata.yaml" and the "cluster.idx" files.
  """
  @spec get_all_paths(String.t()) :: {:ok, [String.t()]} | {:error, any}
  def get_all_paths("CC-MAIN-" <> _rest = crawl_id, headers \\ [], options \\ [])
      when is_binary(crawl_id) do
    url = all_paths_url(crawl_id)

    case HTTPoison.get(url, headers, options) do
      {:ok, %HTTPoison.Response{body: body}} ->
        {:ok, :zlib.gunzip(body) |> String.split("\n", trim: true)}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Returns URL of the file containing the index paths for a given crawl ID.
  """
  @spec all_paths_url(String.t()) :: String.t()
  def all_paths_url("CC-MAIN-" <> _rest = crawl_id) do
    @s3_base_url <> "crawl-data/" <> crawl_id <> "/cc-index.paths.gz"
  end

  @doc """
  Returns URL of the index file.

  ## Examples

      iex> CommonCrawl.Index.url("CC-MAIN-2017-34", "cdx-00203.gz")
      "https://data.commoncrawl.org/cc-index/collections/CC-MAIN-2017-34/indexes/cdx-00203.gz"

  """
  @spec url(String.t(), String.t()) :: String.t()
  def url("CC-MAIN-" <> _rest = crawl_id, filename) do
    @s3_base_url <> "cc-index/collections/#{crawl_id}/indexes/#{filename}"
  end

  @doc """
  Fetches a gzipped index file.
  """
  @spec get(String.t(), String.t()) :: {:ok, binary} | {:error, any}
  def get("CC-MAIN-" <> _rest = crawl_id, filename, headers \\ [], options \\ []) do
    url = url(crawl_id, filename)

    case HTTPoison.get(url, headers, options) do
      {:ok, %HTTPoison.Response{body: body}} ->
        {:ok, body}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Parses a line of an index file.
  """
  @spec parser(Enum.t()) :: {:ok, {String.t(), integer(), map()}} | {:error, any}
  def parser(line) do
    with [search_key, timestamp, json] <- String.split(line, " ", parts: 3),
         {timestamp, ""} <- Integer.parse(timestamp),
         {:ok, map} <- Jason.decode(json) do
      {:ok, {search_key, timestamp, map}}
    else
      other -> {:error, {line, other}}
    end
  end

  @doc """
  Fetches the cluster.idx file.
  """
  @spec get_cluster_idx(String.t()) :: {:ok, binary} | {:error, any}
  def get_cluster_idx("CC-MAIN-" <> _rest = crawl_id, headers \\ [], options \\ []) do
    url = cluster_idx_url(crawl_id)

    case HTTPoison.get(url, headers, options) do
      {:ok, %HTTPoison.Response{body: body}} -> {:ok, body}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Returns URL of the cluster.idx file.

  ## Examples

      iex> CommonCrawl.Index.cluster_idx_url("CC-MAIN-2017-34")
      "https://data.commoncrawl.org/cc-index/collections/CC-MAIN-2017-34/indexes/cluster.idx"

  """
  @spec cluster_idx_url(String.t()) :: String.t()
  def cluster_idx_url("CC-MAIN-" <> _rest = crawl_id) do
    @s3_base_url <> "cc-index/collections/#{crawl_id}/indexes/cluster.idx"
  end

  @doc """
  Filter filenames from cluster.idx with a given function.
  Returns a stream.

  ## Examples

      # Get index files with ".de" TLDs.
      index_files =
        CommonCrawl.Index.filter_cluster_idx(
          cluster_idx,
          fn line -> String.starts_with?(line, "de") end
        )
        |> Enum.to_list()

  """
  @spec filter_cluster_idx(binary, function) :: list
  def filter_cluster_idx(cluster_idx, fun) when is_function(fun, 1) do
    cluster_idx
    |> String.split("\n", trim: true)
    |> Stream.filter(fun)
    |> Stream.map(fn line ->
      [_, index_filename | _] = line |> String.split("\t")

      index_filename
    end)
    |> Stream.uniq()
  end
end
