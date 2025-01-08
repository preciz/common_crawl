defmodule CommonCrawl.WARCTest do
  use ExUnit.Case, async: true
  alias CommonCrawl.WARC

  # %{
  # "digest" => "UGGJSSRBRVWLOGBUN6V7WMIQZE3NVGT7",
  # "encoding" => "ISO-8859-1",
  # "filename" => "crawl-data/CC-MAIN-2024-51/segments/1733066460657.93/warc/CC-MAIN-20241209024434-20241209054434-00482.warc.gz",
  # "languages" => "deu",
  # "length" => "1032",
  # "mime" => "text/html",
  # "mime-detected" => "text/html",
  # "offset" => "373777748",
  # "status" => "200",
  # "url" => "https://muenchen.info/"
  # }

  @sample_warc_filename "crawl-data/CC-MAIN-2024-51/segments/1733066460657.93/warc/CC-MAIN-20241209024434-20241209054434-00482.warc.gz"
  @sample_offset 373_777_748
  @sample_length 1032

  @tag :integration
  test "successfully fetches WARC segment" do
    assert {:ok, response} =
             WARC.get_segment(@sample_warc_filename, @sample_offset, @sample_length)

    assert %{warc: warc, headers: headers, response: response} = response
    assert is_binary(warc)
    assert is_binary(headers)
    assert is_binary(response)

    # Check WARC header format
    assert String.starts_with?(warc, "WARC/1.0")
    assert String.contains?(warc, "WARC-Type:")

    # Check HTTP headers format
    assert String.contains?(headers, "HTTP/1.1")
  end
end
