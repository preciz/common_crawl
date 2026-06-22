# Changelog

## [0.4.1] - 2026-06-22
- Update `req` dependency to version `~> 0.6`

## [0.4.0] - 2026-06-22
- Fix WARC segment decompression range fetching issue by making decompression adaptive
- Handle HTTP error status codes in API responses and file downloads
- Add unit and integration tests for error handling and helper functions
- Disable Dependabot updates
- Update dependencies (`req` and `ex_doc`) and local cached `collinfo.json`
- Implement exponential backoff with jitter retry strategy for fetching indexes
- Stream index partition files entirely in-memory without downloading to disk, resolving disk space leak issues

## [0.3.4] - 2025-07-19
- Implement `stream_host/3` for streaming index entries by host

## [0.3.3] - 2025-07-18
- Update collinfo.json

## [0.3.2] - 2025-05-07
- Remove `Stream.uniq` to fix performance issue

## [0.3.1] - 2025-01-12

### Added
- Added retry mechanism with backoff to `stream/2` function
- New options `:max_attempts` and `:backoff` for `stream/2`

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
