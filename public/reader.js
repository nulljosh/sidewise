import { escapeHTML, safeURL, timeAgo, readFilters, filterURL } from './reader-state.js';
const API = '/api/stories';

function side(bias) { return bias < 0 ? 'l' : bias > 0 ? 'r' : 'c'; }

let allStories = [];
let allLatest = [];
let filter = 'latest';
let query = '';
let source = '';

function renderLatest() {
  const root = document.getElementById('stories');
  const q = query.trim().toLowerCase();
  const items = allLatest.filter(x =>
    (!source || x.outlet === source) && (!q || x.title.toLowerCase().includes(q)));
  root.innerHTML = items.length
    ? items.map(x => `<a class="item" href="${safeURL(x.link)}" target="_blank" rel="noopener">
        <h2>${escapeHTML(x.title)}</h2><span class="o">${escapeHTML(x.outlet)}${x.ts ? ' · ' + timeAgo(x.ts) : ''}</span></a>`).join('')
    : '<p class="muted">No headlines match.</p>';
}

function render() {
  if (filter === 'latest') return renderLatest();
  const root = document.getElementById('stories');
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
    const el = document.createElement('div');
    el.className = 'card story';
    el.innerHTML = `
      <h2>${escapeHTML(s.title)}${s.developing ? '<span class="tag-blindspot">developing</span>' : ''}${s.blindspot ? '<span class="tag-blindspot">blindspot</span>' : ''}</h2>
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
    t.setAttribute('aria-pressed', String(t.dataset.f === filter));
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
