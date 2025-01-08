defmodule CommonCrawl.IndexAPITest do
  use ExUnit.Case, async: true
  alias CommonCrawl.IndexAPI

  @tag :integration
  test "successfully fetches index data" do
    [%{"cdx-api" => cdx_api_url} | _] = CommonCrawl.collinfo()

    query = %{
      "url" => "commoncrawl.org/*",
      "limit" => "3"
    }

    assert {:ok, results} = IndexAPI.get(cdx_api_url, query)
    assert is_list(results)
    assert length(results) <= 3

    # Check structure of returned data
    assert [{key, timestamp, metadata} | _] = results
    assert is_binary(key)
    assert is_integer(timestamp)
    assert is_map(metadata)
    assert Map.has_key?(metadata, "url")
  end

  @tag :integration
  test "get_latest_for_url returns latest entry when found" do
    url = "https://example.com"
    result = IndexAPI.get_latest_for_url(url)

    assert {key, timestamp, metadata} = result
    assert is_binary(key)
    assert is_integer(timestamp)
    assert is_map(metadata)
  end

  @tag :integration
  test "get_latest_for_url returns nil when no entries found" do
    assert nil == IndexAPI.get_latest_for_url("https://non-existing-url.example")
  end

  test "parses response" do
    response_body = File.read!("test/support/api_response")

    assert [
             {"de,berlin)/aufarbeitung/beratung/haertefallfonds/richtlinie-hff.pdf",
              20_211_026_213_821,
              %{
                "digest" => "GGL2NAQQI7KV5JAHBUD6GX6FGWVCOBCC",
                "filename" =>
                  "crawl-data/CC-MAIN-2021-43/segments/1634323587926.9/warc/CC-MAIN-20211026200738-20211026230738-00555.warc.gz",
                "length" => "203813",
                "mime" => "application/pdf",
                "mime-detected" => "application/pdf",
                "offset" => "824104371",
                "status" => "200",
                "url" =>
                  "https://www.berlin.de/aufarbeitung/beratung/haertefallfonds/richtlinie-hff.pdf"
              }}
             | _
           ] = CommonCrawl.IndexAPI.parse_response(response_body)
  end

  test "handles empty response" do
    assert [] = IndexAPI.parse_response("")
  end
end
