defmodule CommonCrawl.IndexTest do
  use ExUnit.Case
  doctest CommonCrawl.Index
  alias CommonCrawl.Index

  @tag :integration
  test "get_all_paths" do
    [%{"id" => crawl_id} | _] = CommonCrawl.collinfo()

    first = "cc-index/collections/#{crawl_id}/indexes/cdx-00000.gz"

    {:ok, [^first | _]} = Index.get_all_paths(crawl_id)
  end

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
             |> Stream.map(&CommonCrawl.Index.parser/1)
             |> Stream.map(fn {:ok, tuple} -> tuple end)
             |> Enum.filter(fn {_search_key, _timestamp, %{"mime-detected" => mime_detected}} ->
               mime_detected == "application/xhtml+xml"
             end)
  end

  test "filters cluster.idx file" do
    cluster_idx = File.read!("test/support/cluster_idx_snippet")

    assert ["cdx-00000.gz"] =
             CommonCrawl.Index.filter_cluster_idx(cluster_idx, fn line ->
               String.starts_with?(line, "15,126,243,162")
             end)
             |> Enum.to_list()
  end
end
