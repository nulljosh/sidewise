export const escapeHTML = value => String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
export function safeURL(value) {
  try { const u = new URL(value); return /^https?:$/.test(u.protocol) ? escapeHTML(u.href) : '#'; }
  catch { return '#'; }
}
export function timeAgo(ts, now = Date.now()) {
  if (!Number.isFinite(ts) || ts <= 0) return '';
  const m = Math.max(0, Math.round((now - ts) / 60000));
  if (m < 60) return `${m}m ago`;
  if (m < 1440) return `${Math.round(m / 60)}h ago`;
  return `${Math.round(m / 1440)}d ago`;
}
export function readFilters(search) {
  const p = new URLSearchParams(search);
  const tab = p.get('tab');
  return { filter: ['latest','all','l','c','r','blindspot'].includes(tab) ? tab : 'latest', query: p.get('q') || '', source: p.get('outlet') || '' };
}
export function filterURL(href, {filter, query, source}) {
  const u = new URL(href);
  for (const [k,v] of Object.entries({tab:filter === 'latest' ? '' : filter, q:query, outlet:source})) {
    if (v) u.searchParams.set(k,v); else u.searchParams.delete(k);
  }
  return u;
}
