defmodule CommonCrawl.Index do
  @moduledoc """
  Interacting with index files of Common Crawl.
  """

  require Logger

  @base_url Application.compile_env(:common_crawl, :base_url, "https://data.commoncrawl.org/")

  @doc """
  Fetches all available index files for a given crawl.
  At the end of the list will be the "metadata.yaml" and the "cluster.idx" files.
  """
  @spec get_all_paths(String.t()) :: {:ok, [String.t()]} | {:error, any}
  def get_all_paths("CC-MAIN-" <> _rest = crawl_id, opts \\ []) when is_binary(crawl_id) do
    url = all_paths_url(crawl_id)

    case Req.get(url, opts) do
      {:ok, %Req.Response{body: body}} ->
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
    @base_url <> "crawl-data/" <> crawl_id <> "/cc-index.paths.gz"
  end

  @doc """
  Returns URL of the index file.

  ## Examples

      iex> CommonCrawl.Index.url("CC-MAIN-2017-34", "cdx-00203.gz")
      "https://data.commoncrawl.org/cc-index/collections/CC-MAIN-2017-34/indexes/cdx-00203.gz"

  """
  @spec url(String.t(), String.t()) :: String.t()
  def url("CC-MAIN-" <> _rest = crawl_id, filename) do
    @base_url <> "cc-index/collections/#{crawl_id}/indexes/#{filename}"
  end

  @doc """
  Fetches a gzipped index file.
  """
  @spec get(String.t(), String.t()) :: {:ok, binary} | {:error, any}
  def get("CC-MAIN-" <> _rest = crawl_id, filename, opts \\ []) do
    url = url(crawl_id, filename)

    case Req.get(url, opts) do
      {:ok, %Req.Response{body: body}} -> {:ok, body}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Parses a line of an index file.
  """
  @spec parser(Enum.t()) :: {:ok, {String.t(), integer(), map()}} | {:error, any}
  def parser(line) do
    with [search_key, timestamp, json] <- String.split(line, " ", parts: 3),
         {timestamp, ""} <- Integer.parse(timestamp),
         {:ok, map} <- JSON.decode(json) do
      {:ok, {search_key, timestamp, map}}
    else
      other -> {:error, {line, other}}
    end
  end

  @doc """
  Fetches the cluster.idx file.
  """
  @spec get_cluster_idx(String.t()) :: {:ok, binary} | {:error, any}
  def get_cluster_idx("CC-MAIN-" <> _rest = crawl_id, opts \\ []) do
    url = cluster_idx_url(crawl_id)

    case Req.get(url, opts) do
      {:ok, %Req.Response{body: body}} -> {:ok, body}
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
    @base_url <> "cc-index/collections/#{crawl_id}/indexes/cluster.idx"
  end

  @doc """
  Creates a stream of parsed index entries from index files.

  ## Options
    * `:preprocess_fun` - function to preprocess the stream before processing (default: & &1)
    * `:dir` - temporary directory for storing downloaded files (default: System.tmp_dir!())

  ## Examples

      # Stream all index entries
      CommonCrawl.Index.stream("CC-MAIN-2024-51")

      # Stream only German domains and shuffle them before processing
      CommonCrawl.Index.stream("CC-MAIN-2024-51", preprocess_fun: fn stream ->
        stream
        |> Stream.filter(&String.starts_with?(&1, "de"))
        |> Enum.shuffle()
      end)
  """
  @spec stream(String.t(), keyword()) :: Enumerable.t()
  def stream(crawl_id, opts \\ []) do
    preprocess_fun = Keyword.get(opts, :preprocess_fun, & &1)
    dir = Keyword.get(opts, :dir, System.tmp_dir!())

    # Get all index files
    {:ok, cluster_idx} = get_cluster_idx(crawl_id)

    cluster_idx
    |> String.split("\n", trim: true)
    |> Stream.uniq()
    |> preprocess_fun.()
    |> Stream.map(fn line ->
      [_, index_filename | _] = line |> String.split("\t")

      index_filename
    end)
    |> Stream.flat_map(fn filename ->
      {:ok, index_gzipped} = get(crawl_id, filename)
      path = Path.join(dir, filename)
      File.write!(path, index_gzipped)

      path
      |> File.stream!([:compressed])
      |> Stream.map(&parser/1)
    end)
    |> Stream.filter(fn
      {:ok, _tuple} ->
        true

      {:error, reason} ->
        Logger.warning("Failed to parse index entry: #{inspect(reason)}")
        false
    end)
    |> Stream.map(fn {:ok, tuple} -> tuple end)
  end
end
