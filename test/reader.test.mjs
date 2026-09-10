import test from 'node:test';
import assert from 'node:assert/strict';
import { escapeHTML, safeURL, timeAgo, readFilters, filterURL } from '../public/reader-state.js';

test('headlines and links cannot inject markup or executable URLs', () => {
  assert.equal(escapeHTML('<img onerror="x">&'), '&lt;img onerror=&quot;x&quot;&gt;&amp;');
  assert.equal(safeURL('javascript:alert(1)'), '#');
  assert.equal(safeURL('data:text/html,test'), '#');
  assert.equal(safeURL('https://example.com/?a=1&b=2'), 'https://example.com/?a=1&amp;b=2');
});
test('filter URLs round trip punctuation and preserve embed and anchors', () => {
  const state = {filter:'blindspot', query:'war & peace', source:'A + B'};
  const url = filterURL('https://example.com/reader.html?embed#top', state);
  assert.deepEqual(readFilters(url.search), state);
  assert.equal(url.searchParams.has('embed'), true);
  assert.equal(url.hash, '#top');
  assert.equal(readFilters('?tab=invalid').filter, 'latest');
  assert.equal(filterURL(url, {filter:'latest',query:'',source:''}).search, '?embed=');
});
test('relative times tolerate missing and future dates', () => {
  assert.equal(timeAgo(0, 100000), '');
  assert.equal(timeAgo(200000, 100000), '0m ago');
  assert.equal(timeAgo(60000, 3660000), '1h ago');
});
