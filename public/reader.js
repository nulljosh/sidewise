import { escapeHTML, safeURL, timeAgo, firstSeenLabel, readFilters, filterURL } from './reader-state.js';
const API = '/api/stories';
const SKELETON = document.getElementById('skeleton').outerHTML;
const SAVE_KEY = 'sidewise:saved';

function side(bias) { return bias < 0 ? 'l' : bias > 0 ? 'r' : 'c'; }

function loadSaved() {
  try { return new Set(JSON.parse(localStorage.getItem(SAVE_KEY)) || []); }
  catch { return new Set(); }
}
function persistSaved() {
  try { localStorage.setItem(SAVE_KEY, JSON.stringify([...saved])); } catch {}
}
function toggleSaved(link) {
  saved.has(link) ? saved.delete(link) : saved.add(link);
  persistSaved();
  render();
}

let allStories = [];
let allLatest = [];
let saved = loadSaved();
let filter = 'latest';
let query = '';
let source = '';
let loaded = false;

function thumb(image) {
  return image ? `<img class="thumb" src="${safeURL(image)}" loading="lazy" width="84" height="60" alt="" onerror="this.hidden=true">` : '';
}
function saveBtn(link) {
  const on = saved.has(link);
  return `<button class="save" data-save="${escapeHTML(link)}" aria-pressed="${on}">${on ? 'Saved' : 'Save'}</button>`;
}

function renderLatest() {
  const root = document.getElementById('stories');
  if (!loaded) { root.innerHTML = SKELETON; return; }
  const q = query.trim().toLowerCase();
  const items = allLatest.filter(x =>
    (!source || x.outlet === source) && (!q || x.title.toLowerCase().includes(q)) &&
    (filter !== 'saved' || saved.has(x.link)));
  root.innerHTML = items.length
    ? items.map(x => `<div class="item">
        ${thumb(x.image)}
        <div class="body"><a href="${safeURL(x.link)}" target="_blank" rel="noopener">
        <h2>${escapeHTML(x.title)}</h2></a><span class="o">${escapeHTML(x.outlet)}${x.ts ? ' · ' + timeAgo(x.ts) : ''}${x.firstSeen ? ' · ' + firstSeenLabel(x.firstSeen) : ''}</span></div>
        ${saveBtn(x.link)}</div>`).join('')
    : `<p class="muted">${filter === 'saved' ? 'No saved stories yet.' : 'No headlines match.'}</p>`;
}

function render() {
  if (filter === 'latest' || filter === 'saved') return renderLatest();
  const root = document.getElementById('stories');
  if (!loaded) { root.innerHTML = SKELETON; return; }
  root.innerHTML = '';
  const q = query.trim().toLowerCase();
  const filtered = allStories.filter(s => {
    if (source && !s.sources.some(x => x.outlet === source)) return false;
    if (q && !s.title.toLowerCase().includes(q)) return false;
    if (filter === 'blindspot') return s.blindspot;
    if (filter === 'all') return true;
    return s.sources.some(x => side(x.bias) === filter);
  });
  if (!filtered.length) {
    root.innerHTML = '<p class="muted">No stories match.</p>';
    return;
  }
  for (const s of filtered) {
    const n = s.counts ? { l: s.counts.left, c: s.counts.center, r: s.counts.right } : { l: 0, c: 0, r: 0 };
    if (!s.counts) for (const x of s.sources) n[side(x.bias)]++;
    const total = n.l + n.c + n.r;
    const link = s.sources[0]?.link;
    const image = s.sources.find(x => x.image)?.image;
    const el = document.createElement('div');
    el.className = 'card story';
    el.innerHTML = `
      ${link ? saveBtn(link) : ''}
      ${thumb(image)}
      <h2>${escapeHTML(s.title)}${s.developing ? '<span class="tag-blindspot">developing</span>' : ''}${s.blindspot ? '<span class="tag-blindspot">blindspot</span>' : ''}</h2>
      ${s.firstSeen ? `<div class="counts">${firstSeenLabel(s.firstSeen)}</div>` : ''}
      <div class="bar">
        <div class="l" style="width:${n.l / total * 100}%"></div>
        <div class="c" style="width:${n.c / total * 100}%"></div>
        <div class="r" style="width:${n.r / total * 100}%"></div>
      </div>
      <div class="counts">${n.l} left · ${n.c} center · ${n.r} right — ${total} publisher${total > 1 ? 's' : ''}</div>
      <details><summary>Coverage</summary>${
        s.sources.map(x => `<a class="src" href="${safeURL(x.link)}" target="_blank" rel="noopener">${escapeHTML(x.title)} <span class="o">— ${escapeHTML(x.outlet)}</span></a>`).join('')
      }</details>`;
    root.appendChild(el);
  }
}

document.getElementById('stories').addEventListener('click', e => {
  const btn = e.target.closest('[data-save]');
  if (!btn) return;
  e.preventDefault();
  toggleSaved(btn.dataset.save);
});

document.getElementById('tabs').addEventListener('click', e => {
  const btn = e.target.closest('.tab');
  if (!btn) return;
  document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
  btn.classList.add('active');
  filter = btn.dataset.f;
  saveFilters();
  render();
});
document.getElementById('q').addEventListener('input', e => { query = e.target.value; saveFilters(true); render(); });
document.getElementById('src').addEventListener('change', e => { source = e.target.value; saveFilters(); render(); });

function syncControls() {
  document.getElementById('q').value = query;
  const sel = document.getElementById('src');
  if (source && ![...sel.options].some(o => o.value === source)) sel.add(new Option(source, source));
  sel.value = source;
  document.querySelectorAll('.tab[data-f]').forEach(t => {
    t.classList.toggle('active', t.dataset.f === filter);
    t.setAttribute('aria-selected', String(t.dataset.f === filter));
  });
}
function saveFilters(replace = false) {
  const url = filterURL(location.href, {filter, query, source});
  if (url.href !== location.href) history[replace ? 'replaceState' : 'pushState'](null, '', url);
  syncControls();
}
function restoreFilters() {
  ({filter, query, source} = readFilters(location.search));
  syncControls();
  render();
}
addEventListener('popstate', restoreFilters);
restoreFilters();
async function load() {
  document.getElementById('retry').hidden = true;
  document.getElementById('updated').textContent = 'Loading stories…';
  try {
    const response = await fetch(API);
    if (!response.ok) throw new Error('Failed to load');
    const {updated, stories, latest, health} = await response.json();
    allStories = stories || [];
    allLatest = latest || [];
    loaded = true;
    const sel = document.getElementById('src');
    sel.replaceChildren(new Option('All sources', ''));
    [...new Set(allLatest.map(x => x.outlet))].sort().forEach(o => sel.add(new Option(o, o)));
    syncControls();
    document.getElementById('updated').textContent =
      `${allLatest.length} headlines · updated ${new Date(updated).toLocaleTimeString()}` +
      (health?.stale ? ' · Showing the last available feed' : '') +
      (health?.down?.length ? ` · Feeds unavailable: ${health.down.join(', ')}` : '');
    render();
  } catch {
    document.getElementById('updated').textContent = 'Failed to load stories.';
    document.getElementById('retry').hidden = false;
  }
}
document.getElementById('retry').addEventListener('click', load);
load();
