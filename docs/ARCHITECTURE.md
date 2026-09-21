# Architecture

Sidewise is an RSS news reader across 22 news outlets. One Cloudflare Worker serves the feed: a flat Latest feed (reverse chronological) and a Ground News-style bias view (same story clustered by outlet). The worker fetches every source, deduplicates by title-keyword overlap, tags political bias, and flags blindspots (stories covered by one side only).

## How it runs

On request to `worker.js`, the route handler calls functions in `src/` (which are testable without Worker runtime). `loadItems()` fetches every feed in `src/feeds.js` in parallel (RSS 2.0 or Atom), caches the combined result ~2 min via Cache API. Failed feeds fall back to the previous good pull; if more than half fail, the response is marked `degraded: true` and `/api/health` returns 503. `parseItems()` extracts title, link, and publish date (tries `pubDate`, `dc:date`, `published`, `updated`; 0 if absent). `storyClustering()` groups headlines by title-keyword overlap (naive O(n²), sufficient for current outlet count). `stories()` returns two views: `latest` (flat, dateless sink to bottom), `stories` (clustered, with bias tags and blindspot flags). `public/reader.html` is the interactive web app; it defaults to Latest and can tab to the bias view. Responses go `no-store` to bypass CDN query-string caching; responses are stale while the feed pull is still in the cache TTL.

The `/mcp` endpoint wraps the same logic in JSON-RPC for in-browser agents.

## Files

| File | What it owns |
|---|---|
| `worker.js` | Cloudflare Worker entry point: routing, error handling, CORS |
| `src/feeds.js` | Feed list: `[outlet, bias, url, publisher?]` rows; `publisher` avoids duplicate-counting one newsroom's two feeds |
| `src/parse.js` | RSS/Atom parsing: date extraction (tries multiple field names), tag stripping, entity unescaping |
| `src/stories.js` | Story clustering and deduplication by title-keyword overlap, bias tagging, blindspot detection |
| `src/load.js` | Parallel feed fetching with failure recovery: half-failure fallback, degraded flag, Cache API integration |
| `src/mcp.js` | JSON-RPC MCP endpoint: `get_news`, `get_blindspots`, `compare_coverage`, `get_feed_health` |
| `public/index.html` | Marketing landing page, deployed static |
| `public/reader.html` | Interactive web app: Latest feed (default), bias view (tabs), source picker, search, sort |
| `public/reader.js` | Client-side feed rendering: fetch from `/api/stories`, render list, tabs, filters |
| `public/style.css` | Reader styling |
| `check-feeds.mjs` | Feed health check: validates recency (not just item count), runs on every addition |
| `test/` | Unit tests (95 checks): parse, stories, load, mcp, no network or Worker runtime |
| `wrangler.toml` | Worker config: Cloudflare Pages static assets, cache API, worker route |
| `ios/Sources/Shared/SidewiseApp.swift` | iOS/macOS app entry point with window group and share overlay (unified native app) |
| `ios/Sources/Shared/Views/ContentView.swift` | Main native app view: feed list, filters (outlet, bias, search), bias view tab switcher |
| `ios/Sources/Shared/Views/StoryRow.swift` | Story list item: headline, outlet, bias indicator, publish date |
| `ios/Sources/Shared/Views/StoryDetailView.swift` | Full story detail page: outlet links, publication time, related stories by bias |
| `ios/Sources/Shared/Views/BiasBar.swift` | Bias distribution visualization: stacked bars per outlet showing left/center/right spectrum |
| `ios/Sources/Shared/Models/Story.swift` | Story data model: headline, outlet, link, publish date, bias tag, blindspot flag |
| `ios/Sources/Shared/Services/NewsService.swift` | Native wrapper around `/api/stories`: fetches, parses, filters by outlet/bias/search, handles cache |
| `ios/Tests/StoryTests.swift` | Unit tests for Story model and NewsService (filter logic, deduplication, bias tagging) |
| `watchos/SidewiseWatchApp.swift` | watchOS app entry point with window group |
| `watchos/ContentView.swift` | watchOS news reader: story list, limited detail view (compact display, 2-3 lines per story) |
| `watchos/Story.swift` | Story model for watchOS (mirrors iOS model but optimized for small screen rendering) |
| `Package.swift` + `tui/main.swift` | SwiftPM target for CLI reader: fetches `/api/stories` and renders a paginated feed in the terminal (static render) |

## Feed structure

Each feed entry is `[outlet, bias, url, publisher?]`:
- `outlet`: display name (Fox, BBC, WSJ, etc)
- `bias`: `"left"`, `"center-left"`, `"center"`, `"center-right"`, `"right"`
- `url`: RSS/Atom feed endpoint
- `publisher`: optional; defaults to `outlet`. Used to group one newsroom's multiple feeds (e.g., NY Post + NY Post Opinion both have `publisher: "NY Post"`)

Add a new source by appending a row and running `npm run feeds` to validate recency.

## Caching

Feed pulls (the combined result from all sources) are cached ~2 min via Cache API under a constant key. API responses go `no-store` so CDN does not cache them by query string. A fresh deploy still serves a stale pull until the Cache TTL expires (expected behavior, not a bug).

## Failure handling

If a feed fails to fetch or returns no items, `loadItems` logs the error but continues. If more than half of all feeds fail, the pull is marked `degraded: true`, `/api/health` returns 503, and the response falls back to the last good pull (marked `stale: true`). The last good pull is never overwritten by a degraded one.

## Story clustering

`storyClustering()` groups stories by extracting keywords from each title and comparing overlap. Two stories with overlapping keywords (e.g., "Biden" and "Middle East") are clustered as the same story. This is O(n²) and naive but sufficient for ~60 unique stories per day across 22 outlets. A future optimization could use embeddings instead of keyword overlap.

## Gotchas

- The fake Cache API in tests must clone on `match()` to mimic the real behavior (it returns a fresh Response each time).
- `caches` does not exist outside Workers. `loadItems` silently falls back to uncached mode instead of throwing.
- Outlet and publisher counts are scattered across FEEDS, worker.js, and prose docs. Always derive them from `FEEDS.length` instead of hardcoding.
- Feeds can be "zombies": returning 200 OK with a frozen snapshot from years ago. Only `npm run feeds` (which checks recency) catches this; item count alone is insufficient.
