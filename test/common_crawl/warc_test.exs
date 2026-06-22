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

  @tag :integration
  test "returns http_error for non-existent WARC file" do
    assert {:error, {:http_error, 404}} =
             WARC.get_segment("non-existent-file.warc.gz", 0, 100)
  end

  describe "parse_response_body/1" do
    test "parses typical CRLF-terminated WARC and HTTP header structure" do
      input = "WARC/1.0\r\nWARC-Type: response\r\n\r\nHTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nhello"
      assert [warc, headers, body] = WARC.parse_response_body(input)
      assert warc == "WARC/1.0\r\nWARC-Type: response"
      assert headers == "HTTP/1.1 200 OK\r\nContent-Length: 5"
      assert body == "hello"
    end

    test "parses LF-terminated WARC and HTTP header structure" do
      input = "WARC/1.0\nWARC-Type: response\n\nHTTP/1.1 200 OK\nContent-Length: 5\n\nhello"
      assert [warc, headers, body] = WARC.parse_response_body(input)
      assert warc == "WARC/1.0\nWARC-Type: response"
      assert headers == "HTTP/1.1 200 OK\nContent-Length: 5"
      assert body == "hello"
    end

    test "parses mixed line endings (CRLF and LF)" do
      input = "WARC/1.0\r\nWARC-Type: response\n\nHTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nhello"
      assert [warc, headers, body] = WARC.parse_response_body(input)
      assert warc == "WARC/1.0\r\nWARC-Type: response"
      assert headers == "HTTP/1.1 200 OK\r\nContent-Length: 5"
      assert body == "hello"
    end

    test "preserves binary payloads with invalid UTF-8 sequences" do
      binary_payload = <<0xFF, 0xFE, 0x00, 0x01, 0x12, 0x34, 0x0D, 0x0A>>
      input = "WARC/1.0\r\n\r\nHTTP/1.1 200 OK\r\n\r\n" <> binary_payload
      assert [warc, headers, body] = WARC.parse_response_body(input)
      assert warc == "WARC/1.0"
      assert headers == "HTTP/1.1 200 OK"
      assert body == binary_payload
    end

    test "trims leading whitespace but preserves trailing whitespace in the payload" do
      binary_payload = "hello \r\n "
      input = "\r\n\n WARC/1.0\r\n\r\nHTTP/1.1 200 OK\r\n\r\n" <> binary_payload
      assert [warc, headers, body] = WARC.parse_response_body(input)
      assert warc == "WARC/1.0"
      assert headers == "HTTP/1.1 200 OK"
      assert body == binary_payload
    end

    test "correctly handles incomplete payloads" do
      assert ["WARC/1.0"] = WARC.parse_response_body("WARC/1.0")
      assert ["WARC/1.0", "HTTP/1.1 200 OK"] = WARC.parse_response_body("WARC/1.0\r\n\r\nHTTP/1.1 200 OK")
    end

    test "uncompresses gzipped input before parsing" do
      raw_content = "WARC/1.0\r\n\r\nHTTP/1.1 200 OK\r\n\r\nhello"
      gzipped = :zlib.gzip(raw_content)
      assert [warc, headers, body] = WARC.parse_response_body(gzipped)
      assert warc == "WARC/1.0"
      assert headers == "HTTP/1.1 200 OK"
      assert body == "hello"
    end
  end
end
