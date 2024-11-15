defmodule CommonCrawl.IndexAPITest do
  use ExUnit.Case, async: true
  doctest CommonCrawl.IndexAPI

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
end
