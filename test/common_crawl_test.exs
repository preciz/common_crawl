defmodule CommonCrawlTest do
  use ExUnit.Case, async: true

  test "returns collinfo" do
    assert [
             %{
               "cdx-api" => "https://index.commoncrawl.org/" <> _,
               "id" => "CC-MAIN-" <> _,
               "name" => _name,
               "timegate" => "https://index.commoncrawl.org/" <> _
             }
             | _
           ] = CommonCrawl.collinfo()
  end

  @tag :integration
  test "fetches current collinfo" do
    assert {:ok, [%{} | _]} = CommonCrawl.get_collinfo()
  end

  @tag :integration
  test "updates collinfo" do
    assert :ok = CommonCrawl.update_collinfo!()
  end

  @tag :integration
  test "gets latest data for existing URL" do
    url = "https://example.com"
    assert {:ok, result} = CommonCrawl.get_latest_for_url(url)

    assert is_map(result)
    assert is_binary(result.warc)
    assert is_binary(result.headers)
    assert is_binary(result.response)
  end

  @tag :integration
  test "returns error for non-existent URL" do
    url = "https://this-definitely-does-not-exist-12345.com"
    assert {:error, :not_found} = CommonCrawl.get_latest_for_url(url)
  end
end
