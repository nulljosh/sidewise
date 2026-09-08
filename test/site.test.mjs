// The static site has no runtime of its own, so nothing else in test/ would catch the two
// ways it has actually broken: a header or a wrong href silently killing the landing page's
// live demo, and the outlet count drifting apart across the files that quote it.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { FEEDS, OUTLETS } from '../src/feeds.js';

const read = rel => readFileSync(fileURLToPath(new URL('../' + rel, import.meta.url)), 'utf8');
const PAGES = readdirSync(fileURLToPath(new URL('../public', import.meta.url)))
  .filter(f => f.endsWith('.html'));

test('the site lets itself be framed, so the landing demo can run the real reader', () => {
  const headers = read('public/_headers');
  // X-Frame-Options has no 'self' — DENY blocks same-origin framing too, which is exactly
  // how the demo ended up an empty phone. SAMEORIGIN still refuses every other site.
  assert.match(headers, /X-Frame-Options: SAMEORIGIN/,
    'DENY would blank the landing page demo; cross-origin framing is still refused');
  const csp = headers.match(/Content-Security-Policy: (.*)/)[1];
  assert.match(csp, /frame-ancestors 'self'/, "frame-ancestors 'none' blanks the demo too");
  assert.match(csp, /frame-src 'self'/, 'the landing page needs to be allowed to open the frame');
});

test('the landing demo frames the reader, not the app-store page', () => {
  const index = read('public/index.html');
  const src = index.match(/id="demoApp"[^>]*data-src="([^"]+)"/);
  assert.ok(src, 'the demo iframe should carry its target in data-src');
  assert.match(src[1], /^\/reader\.html\?embed\b/,
    'the demo advertises "the app, live", so it has to load the reader');
  // A relative src set before the frame is measured is the only wiring the demo needs;
  // if the assignment goes away the frame stays blank with no error anywhere.
  assert.match(index, /iframe\.src = iframe\.dataset\.src/);
});

test('the reader implements the ?embed mode the demo asks for', () => {
  const reader = read('public/reader.html');
  assert.match(reader, /\/\[\?&\]embed\\b\/|embed\\b/,
    'reader.html must detect ?embed itself — the landing page cannot style across the frame');
  assert.match(reader, /\.embed .*\{/, 'and must have rules that trim the chrome for it');
});

test('every page draws from the shared theme', () => {
  for (const page of PAGES) {
    const html = read('public/' + page);
    assert.match(html, /<link rel="stylesheet" href="\/?theme\.css">/,
      `${page} should share the site palette rather than redefining it`);
    assert.doesNotMatch(html, /@import url\(['"]https:\/\/heyitsmejosh\.com\/tokens\.css/,
      `${page} should reach tokens.css through theme.css, so the palette has one home`);
  }
});

test('no page hardcodes the outlet count in prose', () => {
  for (const page of PAGES) {
    const html = read('public/' + page);
    assert.doesNotMatch(html, /\b\d+\s+(news\s+)?outlets\b/i,
      `${page} hardcodes an outlet count; it belongs in a <span data-outlets> filled from /api/sources`);
  }
  // …and the placeholder that no-JS visitors see should at least be true today.
  for (const page of ['public/index.html', 'public/app.html']) {
    for (const [, n] of read(page).matchAll(/<span data-outlets>(\d+)<\/span>/g)) {
      assert.equal(Number(n), FEEDS.length, `${page} has a stale no-JS fallback count`);
    }
  }
});

test('the counts baked into the agent-facing files match FEEDS', () => {
  const llms = read('public/llms.txt');
  for (const [, n] of llms.matchAll(/\b(\d+)\s+(?:news outlets|RSS feeds)\b/g)) {
    assert.equal(Number(n), FEEDS.length, 'llms.txt quotes a stale feed count');
  }
  assert.match(read('public/openapi.yaml'), new RegExp(`Headlines from ${FEEDS.length} outlets`));
  assert.match(read('package.json'), new RegExp(`Reads ${FEEDS.length} feeds`));

  // The prose list is the thing that actually goes stale: Washington Post came back and the
  // list did not, which is where the "16" everywhere came from.
  const listed = llms.split('## Outlets')[1].split('##')[0];
  for (const outlet of OUTLETS) {
    assert.ok(listed.includes(outlet), `llms.txt does not list ${outlet}`);
  }
});

test('nothing still links the pre-rename repo', () => {
  for (const file of [...PAGES.map(p => 'public/' + p), 'public/llms.txt']) {
    assert.doesNotMatch(read(file), /github\.com\/nulljosh\/newsline/,
      `${file} links the old repo name`);
  }
});

test('the service worker precaches the stylesheets the pages now depend on', () => {
  const sw = read('public/sw.js');
  for (const asset of ['/theme.css', '/devices.css']) {
    assert.ok(sw.includes(`"${asset}"`), `sw.js should precache ${asset}`);
  }
});
