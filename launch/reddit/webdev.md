Note: no karma/flair gate, but frame as "I built X to solve Y", not an ad.

Title: I built a bias-tagged news API without embeddings or an LLM call

Body: Wanted a clean way to see the same story from across the political spectrum, so I built Sidewise: 16 feeds from 14 newsrooms, clustered by title-keyword overlap instead of embeddings, tagged left/center/right, with blindspot detection for stories only one side covers.

It's one Cloudflare Worker, no model cost, no external call in the hot path. Free JSON API and an MCP server on top of the same data, no key required.

Would like feedback on the API shape if anyone wants to build on it.

https://sidewise.heyitsmejosh.com
