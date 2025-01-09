# CommonCrawl

[![test](https://github.com/preciz/common_crawl/actions/workflows/test.yml/badge.svg)](https://github.com/preciz/common_crawl/actions/workflows/test.yml)

Work with Common Crawl data from Elixir.

## Installation

Add `common_crawl` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:common_crawl, "~> 0.3.0"}
  ]
end
```

## Usage Examples

```elixir
# Get list of available crawls
crawls = CommonCrawl.collinfo()

# Search for URLs in the index
crawl = List.first(crawls)
{:ok, results} = CommonCrawl.IndexAPI.get(crawl["cdx-api"], %{
  "url" => "example.com/*",
  "output" => "json"
})

# Download webpage content from WARC file
{url, timestamp, metadata} = List.first(results)
{:ok, segment} = CommonCrawl.WARC.get_segment(
  metadata["filename"],
  metadata["offset"],
  metadata["length"]
)

# Work with raw index files
{:ok, index_paths} = CommonCrawl.Index.get_all_paths("CC-MAIN-2021-43")
{:ok, index_file} = CommonCrawl.Index.get("CC-MAIN-2021-43", List.first(index_paths))
```

## Docs
The docs can be found at [https://hexdocs.pm/common_crawl](https://hexdocs.pm/common_crawl).

