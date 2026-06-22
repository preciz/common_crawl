defmodule CommonCrawl.Index do
  @moduledoc """
  Interacting with index files of Common Crawl.
  """
  import CommonCrawl.Helpers
  require Logger

  @base_url Application.compile_env(:common_crawl, :base_url, "https://data.commoncrawl.org/")

  @doc """
  Fetches all available index files for a given crawl.
  At the end of the list will be the "metadata.yaml" and the "cluster.idx" files.

  ## Examples

      iex> CommonCrawl.Index.get_all_paths("CC-MAIN-2024-51")
      {:ok, [
        "cc-index/collections/CC-MAIN-2024-51/indexes/cdx-00000.gz",
        "cc-index/collections/CC-MAIN-2024-51/indexes/cdx-00001.gz",
        # ... more index files
        "cc-index/collections/CC-MAIN-2024-51/indexes/metadata.yaml",
        "cc-index/collections/CC-MAIN-2024-51/indexes/cluster.idx"
      ]}

  """
  @spec get_all_paths(String.t()) :: {:ok, [String.t()]} | {:error, any}
  def get_all_paths("CC-MAIN-" <> _rest = crawl_id, opts \\ []) when is_binary(crawl_id) do
    url = all_paths_url(crawl_id)

    case Req.get(url, opts) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, :zlib.gunzip(body) |> String.split("\n", trim: true)}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:http_error, status}}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Returns URL of the file containing the index paths for a given crawl ID.

  ## Examples

      iex> CommonCrawl.Index.all_paths_url("CC-MAIN-2017-34")
      "https://data.commoncrawl.org/crawl-data/CC-MAIN-2017-34/cc-index.paths.gz"

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

  ## Examples

      iex> CommonCrawl.Index.get("CC-MAIN-2024-51", "cdx-00000.gz")
      {:ok, <<31, 139, 8, 0, 0, 0, 0, 0, 0, 3, ...>>}

  """
  @spec get(String.t(), String.t()) :: {:ok, binary} | {:error, any}
  def get("CC-MAIN-" <> _rest = crawl_id, filename, opts \\ []) do
    url = url(crawl_id, filename)

    case Req.get(url, opts) do
      {:ok, %Req.Response{status: 200, body: body}} -> {:ok, body}
      {:ok, %Req.Response{status: status}} -> {:error, {:http_error, status}}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Parses a line of an index file into a tuple containing the search key, timestamp, and metadata map.

  ## Examples

      iex> line = "com,example)/ 20240108123456 {\"url\": \"http://www.example.com\"}"
      iex> CommonCrawl.Index.parser(line)
      {:ok, {"com,example)/", 20240108123456, %{"url" => "http://www.example.com"}}}

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

  ## Examples

      iex> CommonCrawl.Index.get_cluster_idx("CC-MAIN-2024-51")
      {:ok, "0,100,22,165)/ 20241209080420..."}

  """
  @spec get_cluster_idx(String.t()) :: {:ok, binary} | {:error, any}
  def get_cluster_idx("CC-MAIN-" <> _rest = crawl_id, opts \\ []) do
    url = cluster_idx_url(crawl_id)

    case Req.get(url, opts) do
      {:ok, %Req.Response{status: 200, body: body}} -> {:ok, body}
      {:ok, %Req.Response{status: status}} -> {:error, {:http_error, status}}
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
    * `:max_attempts` - maximum number of retry attempts for fetching cluster.idx (default: 3)
    * `:backoff` - milliseconds to wait between retry attempts (default: 500)

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
    max_attempts = Keyword.get(opts, :max_attempts, 3)
    backoff = Keyword.get(opts, :backoff, 500)
    dir = Keyword.get(opts, :dir, System.tmp_dir!())

    # Get all index files
    {:ok, cluster_idx} =
      with_attempts(fn -> get_cluster_idx(crawl_id) end, max_attempts, backoff)

    cluster_idx
    |> String.split("\n", trim: true)
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

  @doc """
  Streams parsed index entries for the specified host.

  This function wraps `stream/2`, applying a filter to include only those entries whose URL host matches the given `host`.

  ## Examples

      iex> CommonCrawl.Index.stream_host("CC-MAIN-2024-51", "www.example.com") |> Enum.take(2)
      [
        {"com,example)/", 20240108123456, %{"url" => "http://www.example.com"}},
        {"com,example)/", 20240108123457, %{"url" => "http://www.example.com/page2"}}
      ]
  """
  @spec stream_host(String.t(), String.t(), keyword()) :: Enumerable.t()
  def stream_host(crawl_id, host, opts \\ []) do
    preprocess_fun = fn stream ->
      host_preprocess_fun(stream, host)
      |> (opts[:preprocess_fun] || (& &1)).()
    end

    opts = Keyword.put(opts, :preprocess_fun, preprocess_fun)

    stream(crawl_id, opts)
    |> Stream.filter(fn {_, _, %{"url" => url}} ->
      URI.parse(url).host == host
    end)
  end

  @doc false
  def host_preprocess_fun(index_list, host) do
    start_pattern = search_key_host_start_pattern(host)

    end_index = index_list |> Enum.find_index(&(&1 > start_pattern))
    start_index = max(end_index - 1, 0)

    index_list
    |> Enum.slice(start_index..end_index)
  end

  @doc false
  def search_key_host_start_pattern(host) when is_binary(host) do
    host
    |> String.split(".")
    |> Enum.reverse()
    |> Enum.take(2)
    |> Enum.join(",")
    |> Kernel.<>(")")
  end
end

