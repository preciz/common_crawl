defmodule CommonCrawl.WARCTest do
  use ExUnit.Case, async: true
  alias CommonCrawl.WARC

  # {"com,example)/", 20241114232932, %{
  #  "digest" => "JI6OR3QR4CI526JD6TMMNZNV4QPMPQCH",
  #  "encoding" => "UTF-8",
  #  "filename" => ,
  #  "languages" => "eng",
  #  "length" => "1258",
  #  "mime" => "text/html",
  #  "mime-detected" => "text/html",
  #  "offset" => "669481092",
  #  "status" => "200",
  #  "url" => "https://www.example.com"
  # }}

  @sample_warc_filename "crawl-data/CC-MAIN-2024-46/segments/1730477397531.96/warc/CC-MAIN-20241114225955-20241115015955-00238.warc.gz"
  @sample_offset 669_481_092
  @sample_length 1258

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
