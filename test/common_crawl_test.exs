defmodule CommonCrawlTest do
  use ExUnit.Case
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
end
