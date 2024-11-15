defmodule CommonCrawl.IndexTest do
  use ExUnit.Case, async: true
  doctest CommonCrawl.Index
  alias CommonCrawl.Index

  @tag :integration
  test "get_all_paths" do
    [%{"id" => crawl_id} | _] = CommonCrawl.collinfo()

    first = "cc-index/collections/#{crawl_id}/indexes/cdx-00000.gz"

    {:ok, [^first | _]} = Index.get_all_paths(crawl_id)
  end

  @tag :integration
  test "get_cluster_idx successfully fetches cluster.idx file" do
    [%{"id" => crawl_id} | _] = CommonCrawl.collinfo()

    assert {:ok, body} = Index.get_cluster_idx(crawl_id)
    assert is_binary(body)
  end

  @tag :integration
  test "get successfully fetches an index file" do
    [%{"id" => crawl_id} | _] = CommonCrawl.collinfo()

    assert {:ok, body} = Index.get(crawl_id, "cdx-00000.gz")
    assert is_binary(body)
  end

  test "filters cluster.idx file" do
    cluster_idx = File.read!("test/support/cluster_idx_snippet")

    assert ["cdx-00000.gz"] =
             Index.filter_cluster_idx(cluster_idx, fn line ->
               String.starts_with?(line, "15,126,243,162")
             end)
             |> Enum.to_list()
  end

  describe "url generation" do
    test "all_paths_url/1" do
      assert Index.all_paths_url("CC-MAIN-2021-43") ==
               "https://data.commoncrawl.org/crawl-data/CC-MAIN-2021-43/cc-index.paths.gz"
    end

    test "url/2" do
      assert Index.url("CC-MAIN-2021-43", "cdx-00000.gz") ==
               "https://data.commoncrawl.org/cc-index/collections/CC-MAIN-2021-43/indexes/cdx-00000.gz"
    end

    test "cluster_idx_url/1" do
      assert Index.cluster_idx_url("CC-MAIN-2021-43") ==
               "https://data.commoncrawl.org/cc-index/collections/CC-MAIN-2021-43/indexes/cluster.idx"
    end
  end

  describe "parser" do
    test "parses index file" do
      stream = File.stream!("test/support/index_snippet")

      assert [
               {"com,blogspot,learningenglish-esl)/2010/08/billy-goats-gruff-story-masks.html",
                20_211_028_134_649,
                %{
                  "charset" => "UTF-8",
                  "digest" => "E3SJNTPZTMI3MYV3TIAHLPG4L4MZFHT5",
                  "filename" =>
                    "crawl-data/CC-MAIN-2021-43/segments/1634323588341.58/warc/CC-MAIN-20211028131628-20211028161628-00591.warc.gz",
                  "languages" => "eng,spa",
                  "length" => "16898",
                  "mime" => "text/html",
                  "mime-detected" => "application/xhtml+xml",
                  "offset" => "469631771",
                  "status" => "200",
                  "url" =>
                    "https://learningenglish-esl.blogspot.com/2010/08/billy-goats-gruff-story-masks.html"
                }}
               | _
             ] =
               stream
               |> Stream.map(&Index.parser/1)
               |> Stream.map(fn {:ok, tuple} -> tuple end)
               |> Enum.filter(fn {_search_key, _timestamp, %{"mime-detected" => mime_detected}} ->
                 mime_detected == "application/xhtml+xml"
               end)
    end

    test "handles invalid line format" do
      invalid_line = "not enough parts"
      assert {:error, {^invalid_line, _}} = Index.parser(invalid_line)

      invalid_timestamp = "key invalid_timestamp {}"
      assert {:error, {^invalid_timestamp, _}} = Index.parser(invalid_timestamp)
    end

    test "handles invalid JSON" do
      invalid_json = "key 123456789 {invalid json}"
      assert {:error, {^invalid_json, _}} = Index.parser(invalid_json)
    end
  end
end
