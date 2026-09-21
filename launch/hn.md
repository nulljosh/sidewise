Show HN: Sidewise – bias-tagged news clustering without embeddings or an LLM

Sidewise pulls sixteen feeds from fourteen newsrooms, clusters same-day stories together, tags each source left, center or right, and flags blindspots: stories only one side is covering. Same-story detection is done with title-keyword overlap instead of embeddings or an LLM call, so the whole pipeline runs on one Cloudflare Worker with no model cost and nothing in the hot path but string matching. There is a reader, a free API, and an MCP server. Web at sidewise.heyitsmejosh.com, source on GitHub.
