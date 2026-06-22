defmodule CommonCrawlMockTest do
  use ExUnit.Case, async: true
  use Mimic

  alias CommonCrawl.{Index, IndexAPI, WARC}

  describe "CommonCrawl core functions" do
    test "get_collinfo/1 success" do
      body = [%{"id" => "CC-MAIN-2024-51"}]

      Req
      |> Mimic.expect(:get, fn "https://index.commoncrawl.org/collinfo.json", _opts ->
        {:ok, %Req.Response{status: 200, body: body}}
      end)

      assert {:ok, ^body} = CommonCrawl.get_collinfo()
    end

    test "get_collinfo/1 error statuses" do
      Req
      |> Mimic.expect(:get, fn "https://index.commoncrawl.org/collinfo.json", _opts ->
        {:ok, %Req.Response{status: 404}}
      end)

      assert {:error, {:http_error, 404}} = CommonCrawl.get_collinfo()
    end

    test "get_collinfo/1 network error" do
      Req
      |> Mimic.expect(:get, fn "https://index.commoncrawl.org/collinfo.json", _opts ->
        {:error, :timeout}
      end)

      assert {:error, :timeout} = CommonCrawl.get_collinfo()
    end

    test "update_collinfo!/0 updates cached file" do
      body = [%{"id" => "CC-MAIN-2024-51"}]

      Req
      |> Mimic.expect(:get, fn "https://index.commoncrawl.org/collinfo.json", _opts ->
        {:ok, %Req.Response{status: 200, body: body}}
      end)

      original = File.read!("priv/collinfo.json")

      try do
        assert :ok = CommonCrawl.update_collinfo!()
      after
        File.write!("priv/collinfo.json", original)
      end
    end

    test "get_latest_for_url/2 when entry exists" do
      warc_filename = "crawl-data/CC-MAIN-2024-51/...warc.gz"

      Req
      |> Mimic.expect(:get, 1, fn url, _opts ->
        url_str = to_string(url)
        assert String.starts_with?(url_str, "https://index.commoncrawl.org/")

        body =
          "com,example)/ 20241214183829 {\"url\": \"https://example.com\", \"offset\": \"100\", \"length\": \"50\", \"filename\": \"#{warc_filename}\"}"

        {:ok, %Req.Response{status: 200, body: body}}
      end)
      |> Mimic.expect(:get, 1, fn url, _opts ->
        url_str = to_string(url)
        assert String.starts_with?(url_str, "https://data.commoncrawl.org/")
        warc_content = "WARC/1.0\r\n\r\nHTTP/1.1 200 OK\r\n\r\nhello"
        {:ok, %Req.Response{status: 200, body: warc_content}}
      end)

      assert {:ok, %{response: "hello"}} =
               CommonCrawl.get_latest_for_url("https://example.com", crawls_to_check: 1)
    end

    test "get_latest_for_url/2 when not found" do
      Req
      |> Mimic.expect(:get, 1, fn _url, _opts ->
        {:ok, %Req.Response{status: 404}}
      end)

      assert {:error, :not_found} =
               CommonCrawl.get_latest_for_url("https://example.com", crawls_to_check: 1)
    end
  end

  describe "CommonCrawl.IndexAPI" do
    test "get/3 success" do
      Req
      |> Mimic.expect(:get, fn url, _opts ->
        assert String.starts_with?(url, "https://index.example.com")
        body = "com,example)/ 20241214183829 {\"url\": \"https://example.com\"}"
        {:ok, %Req.Response{status: 200, body: body}}
      end)

      assert {:ok, [{"com,example)/", 20_241_214_183_829, %{"url" => "https://example.com"}}]} =
               IndexAPI.get("https://index.example.com", %{"url" => "https://example.com"})
    end

    test "get/3 error response" do
      Req
      |> Mimic.expect(:get, fn _url, _opts ->
        {:ok, %Req.Response{status: 500}}
      end)

      assert {:error, %Req.Response{status: 500}} =
               IndexAPI.get("https://index.example.com", %{"url" => "https://example.com"})
    end

    test "get/3 network error" do
      Req
      |> Mimic.expect(:get, fn _url, _opts ->
        {:error, :nxdomain}
      end)

      assert {:error, :nxdomain} =
               IndexAPI.get("https://index.example.com", %{"url" => "https://example.com"})
    end
  end

  describe "CommonCrawl.WARC" do
    test "get_segment/4 success (200)" do
      Req
      |> Mimic.expect(:get, fn url, opts ->
        assert url == URI.merge("https://data.commoncrawl.org/", "some_file.warc.gz")
        assert {"Range", "bytes=100-149"} in opts[:headers]
        body = "WARC/1.0\r\n\r\nHTTP/1.1 200 OK\r\n\r\nhello"
        {:ok, %Req.Response{status: 200, body: body}}
      end)

      assert {:ok, %{response: "hello"}} = WARC.get_segment("some_file.warc.gz", 100, 50)
    end

    test "get_segment/4 success (206)" do
      Req
      |> Mimic.expect(:get, fn _url, _opts ->
        body = "WARC/1.0\r\n\r\nHTTP/1.1 200 OK\r\n\r\nhello"
        {:ok, %Req.Response{status: 206, body: body}}
      end)

      assert {:ok, %{response: "hello"}} = WARC.get_segment("some_file.warc.gz", 100, 50)
    end

    test "get_segment/4 HTTP error" do
      Req
      |> Mimic.expect(:get, fn _url, _opts ->
        {:ok, %Req.Response{status: 403}}
      end)

      assert {:error, {:http_error, 403}} = WARC.get_segment("some_file.warc.gz", 100, 50)
    end

    test "get_segment/4 parse error (other)" do
      Req
      |> Mimic.expect(:get, fn _url, _opts ->
        {:ok, %Req.Response{status: 200, body: "invalid content"}}
      end)

      assert {:error, {:no_headers_or_response, ["invalid content"]}} =
               WARC.get_segment("some_file.warc.gz", 100, 50)
    end
  end

  describe "CommonCrawl.Index" do
    test "get_all_paths/2 success" do
      paths = "path1\npath2"
      gzipped = :zlib.gzip(paths)

      Req
      |> Mimic.expect(:get, fn url, _opts ->
        assert String.contains?(url, "CC-MAIN-2024-51")
        {:ok, %Req.Response{status: 200, body: gzipped}}
      end)

      assert {:ok, ["path1", "path2"]} = Index.get_all_paths("CC-MAIN-2024-51")
    end

    test "get_all_paths/2 HTTP error" do
      Req
      |> Mimic.expect(:get, fn _url, _opts ->
        {:ok, %Req.Response{status: 404}}
      end)

      assert {:error, {:http_error, 404}} = Index.get_all_paths("CC-MAIN-2024-51")
    end

    test "get_all_paths/2 network error" do
      Req
      |> Mimic.expect(:get, fn _url, _opts ->
        {:error, :econnrefused}
      end)

      assert {:error, :econnrefused} = Index.get_all_paths("CC-MAIN-2024-51")
    end

    test "get/3 success" do
      Req
      |> Mimic.expect(:get, fn _url, _opts ->
        {:ok, %Req.Response{status: 200, body: "index_data"}}
      end)

      assert {:ok, "index_data"} = Index.get("CC-MAIN-2024-51", "cdx-00000.gz")
    end

    test "get/3 HTTP error" do
      Req
      |> Mimic.expect(:get, fn _url, _opts ->
        {:ok, %Req.Response{status: 500}}
      end)

      assert {:error, {:http_error, 500}} = Index.get("CC-MAIN-2024-51", "cdx-00000.gz")
    end

    test "get/3 network error" do
      Req
      |> Mimic.expect(:get, fn _url, _opts ->
        {:error, :timeout}
      end)

      assert {:error, :timeout} = Index.get("CC-MAIN-2024-51", "cdx-00000.gz")
    end

    test "get_cluster_idx/2 success" do
      Req
      |> Mimic.expect(:get, fn _url, _opts ->
        {:ok, %Req.Response{status: 200, body: "cluster_data"}}
      end)

      assert {:ok, "cluster_data"} = Index.get_cluster_idx("CC-MAIN-2024-51")
    end

    test "get_cluster_idx/2 HTTP error" do
      Req
      |> Mimic.expect(:get, fn _url, _opts ->
        {:ok, %Req.Response{status: 500}}
      end)

      assert {:error, {:http_error, 500}} = Index.get_cluster_idx("CC-MAIN-2024-51")
    end

    test "get_cluster_idx/2 network error" do
      Req
      |> Mimic.expect(:get, fn _url, _opts ->
        {:error, :timeout}
      end)

      assert {:error, :timeout} = Index.get_cluster_idx("CC-MAIN-2024-51")
    end

    test "stream/2 streams and parses gzipped index files successfully" do
      cluster_idx_content = "key\tcdx-00000.gz\t100\n"
      index_line = "com,example)/ 20240108123456 {\"url\": \"http://www.example.com\"}\n"
      gzipped_index = :zlib.gzip(index_line)

      Req
      |> Mimic.expect(:get, 1, fn url, _opts ->
        assert String.contains?(url, "cluster.idx")
        {:ok, %Req.Response{status: 200, body: cluster_idx_content}}
      end)
      |> Mimic.expect(:get, 1, fn url, _opts ->
        assert String.contains?(url, "cdx-00000.gz")
        {:ok, %Req.Response{status: 200, body: gzipped_index}}
      end)

      tmp_dir = "test/support/tmp_stream"
      File.mkdir_p!(tmp_dir)

      try do
        result = Index.stream("CC-MAIN-2024-51", dir: tmp_dir) |> Enum.to_list()

        assert [{"com,example)/", 20_240_108_123_456, %{"url" => "http://www.example.com"}}] ==
                 result
      after
        File.rm_rf!(tmp_dir)
      end
    end

    test "stream/2 configures Req retry options correctly" do
      cluster_idx_content = "key\tcdx-00000.gz\t100\n"

      Req
      |> Mimic.expect(:get, 1, fn _url, opts ->
        assert opts[:max_retries] == 2
        assert is_function(opts[:retry_delay], 1)

        retry_delay = opts[:retry_delay]

        delay_0 = retry_delay.(0)
        assert is_integer(delay_0) and delay_0 >= 1 and delay_0 <= 2000

        delay_1 = retry_delay.(1)
        assert is_integer(delay_1) and delay_1 >= 1 and delay_1 <= 4000

        delay_2 = retry_delay.(2)
        assert is_integer(delay_2) and delay_2 >= 1 and delay_2 <= 8000

        delay_5 = retry_delay.(5)
        assert is_integer(delay_5) and delay_5 >= 1 and delay_5 <= 30000

        {:ok, %Req.Response{status: 200, body: cluster_idx_content}}
      end)
      |> Mimic.expect(:get, 1, fn _url, _opts ->
        {:ok, %Req.Response{status: 200, body: []}}
      end)

      assert [] = Index.stream("CC-MAIN-2024-51") |> Stream.take(1) |> Enum.to_list()
    end

    test "stream/2 raises on index partition stream failure" do
      cluster_idx_content = "key\tcdx-00000.gz\t100\n"

      Req
      |> Mimic.expect(:get, 1, fn _url, _opts ->
        {:ok, %Req.Response{status: 200, body: cluster_idx_content}}
      end)
      |> Mimic.expect(:get, 1, fn _url, _opts ->
        {:error, :timeout}
      end)

      assert_raise RuntimeError, ~r/Failed to stream index partition cdx-00000.gz/, fn ->
        Index.stream("CC-MAIN-2024-51") |> Enum.to_list()
      end
    end

    test "stream/2 handles index partition data without trailing newline" do
      cluster_idx_content = "key\tcdx-00000.gz\t100\n"
      index_line = "com,example)/ 20240108123456 {\"url\": \"http://www.example.com\"}"
      gzipped_index = :zlib.gzip(index_line)

      Req
      |> Mimic.expect(:get, 1, fn _url, _opts ->
        {:ok, %Req.Response{status: 200, body: cluster_idx_content}}
      end)
      |> Mimic.expect(:get, 1, fn _url, _opts ->
        {:ok, %Req.Response{status: 200, body: gzipped_index}}
      end)

      tmp_dir = "test/support/tmp_stream_no_nl"
      File.mkdir_p!(tmp_dir)

      try do
        result = Index.stream("CC-MAIN-2024-51", dir: tmp_dir) |> Enum.to_list()

        assert [{"com,example)/", 20_240_108_123_456, %{"url" => "http://www.example.com"}}] ==
                 result
      after
        File.rm_rf!(tmp_dir)
      end
    end

    @tag :capture_log
    test "stream/2 filters out parsing errors" do
      cluster_idx_content = "key\tcdx-00000.gz\t100\n"
      invalid_index_line = "invalid line here\n"
      gzipped_index = :zlib.gzip(invalid_index_line)

      Req
      |> Mimic.expect(:get, 1, fn url, _opts ->
        assert String.contains?(url, "cluster.idx")
        {:ok, %Req.Response{status: 200, body: cluster_idx_content}}
      end)
      |> Mimic.expect(:get, 1, fn url, _opts ->
        assert String.contains?(url, "cdx-00000.gz")
        {:ok, %Req.Response{status: 200, body: gzipped_index}}
      end)

      tmp_dir = "test/support/tmp_stream_err"
      File.mkdir_p!(tmp_dir)

      try do
        result = Index.stream("CC-MAIN-2024-51", dir: tmp_dir) |> Enum.to_list()
        assert [] == result
      after
        File.rm_rf!(tmp_dir)
      end
    end

    test "stream_host/3 filters entries by host" do
      cluster_idx_content =
        "com,apple)/ 2024...\tcdx-00000.gz\t100\ncom,example)/ 2024...\tcdx-00001.gz\t100\n"

      index_line1 = "com,google)/ 20240108123456 {\"url\": \"http://www.google.com\"}\n"
      index_line2 = "com,example)/ 20240108123456 {\"url\": \"http://www.example.com\"}\n"

      Req
      |> Mimic.expect(:get, 1, fn url, _opts ->
        url_str = to_string(url)
        assert String.contains?(url_str, "cluster.idx")
        {:ok, %Req.Response{status: 200, body: cluster_idx_content}}
      end)
      |> Mimic.expect(:get, 1, fn url, _opts ->
        url_str = to_string(url)
        assert String.contains?(url_str, "cdx-00000.gz")
        {:ok, %Req.Response{status: 200, body: :zlib.gzip(index_line1)}}
      end)
      |> Mimic.expect(:get, 1, fn url, _opts ->
        url_str = to_string(url)
        assert String.contains?(url_str, "cdx-00001.gz")
        {:ok, %Req.Response{status: 200, body: :zlib.gzip(index_line2)}}
      end)

      tmp_dir = "test/support/tmp_stream_host"
      File.mkdir_p!(tmp_dir)

      try do
        result =
          Index.stream_host("CC-MAIN-2024-51", "www.example.com", dir: tmp_dir) |> Enum.to_list()

        assert [{"com,example)/", 20_240_108_123_456, %{"url" => "http://www.example.com"}}] ==
                 result
      after
        File.rm_rf!(tmp_dir)
      end
    end
  end
end
