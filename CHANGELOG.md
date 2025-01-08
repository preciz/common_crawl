# Changelog

## [0.3.0] - 2025-01-09

### Added
- New `stream/2` function to efficiently process index entries

### Changed
- Removed `filter_cluster_idx/2` in favor of new streaming API

## [0.2.0] - 2025-01-08

### Added
- `get_latest_for_url/2` function to fetch most recent crawl data for a URL

### Changed
- Switched from Jason to JSON library for JSON encoding/decoding
- Renamed configuration `s3_base_url` to `base_url` for clarity
- Updated minimum Elixir version requirement to 1.18
- Improved documentation with more examples
