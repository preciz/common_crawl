defmodule CommonCrawlTest do
  use ExUnit.Case, async: true
  doctest CommonCrawl

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
end
