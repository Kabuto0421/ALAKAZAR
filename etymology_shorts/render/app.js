'use strict';
// Deterministic frame renderer: window.renderFrame(t) paints the video at t seconds.
// Everything is a pure function of t and the timeline, so frames can be
// captured in any order and by several browser pages in parallel.

const G = { cx: 540, cy: 660, r: 400 };
const CAM_DUR = 1.7;
const $ = (s, el = document) => el.querySelector(s);
const clamp = (x, a = 0, b = 1) => Math.min(b, Math.max(a, x));
const lerp = (a, b, t) => a + (b - a) * t;
const ease = (t) => (t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2);
const easeOut = (t) => 1 - Math.pow(1 - t, 3);
const easeIn = (t) => t * t * t;
const back = (t) => { const c1 = 1.9, c3 = c1 + 1; return 1 + c3 * Math.pow(t - 1, 3) + c1 * Math.pow(t - 1, 2); };
const prog = (t, t0, d) => clamp((t - t0) / d);
const decay = (dt, tau) => (dt < 0 ? 0 : Math.exp(-dt / tau));
const deg = Math.PI / 180;

function rng(seed) {
  let a = seed | 0;
  return () => {
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function el(tag, cls, html) {
  const e = document.createElement(tag);
  if (cls) e.className = cls;
  if (html != null) e.innerHTML = html;
  return e;
}
const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;');
// "{…}" inside a word marks the sounds the episode wants the eye to follow
const hl = (s) => esc(s).replace(/\{([^}]*)\}/g, '<b class="hl">$1</b>');
const SVGNS = 'http://www.w3.org/2000/svg';
function svgEl(tag, attrs = {}) {
  const e = document.createElementNS(SVGNS, tag);
  for (const k in attrs) e.setAttribute(k, attrs[k]);
  return e;
}

let TL, EV, PLACES, LAND, BORDERS;
const GRAT = d3.geoGraticule10();
const proj = d3.geoOrthographic().clipAngle(90).precision(0.35).translate([G.cx, G.cy]);
const geo = d3.geoPath(proj);

/* ------------------------------------------------------------------ camera */

let CAM_KEYS = [];
function staticCam(k, t) {
  return { lon: k.lon + (k.spin || 0) * (t - k.t), lat: k.lat, zoom: k.zoom };
}
function camAt(i, t) {
  const k = CAM_KEYS[i];
  const s = staticCam(k, t);
  if (i === 0) return s;
  const p = (t - k.t) / CAM_DUR;
  if (p >= 1) return s;
  const a = camAt(i - 1, k.t);
  const pc = ease(clamp(p));
  const c = d3.geoInterpolate([a.lon, a.lat], [s.lon, s.lat])(pc);
  const zoomIn = s.zoom > a.zoom;
  const pz = ease(zoomIn ? clamp((p - 0.25) / 0.75) : clamp(p / 0.75));
  const dist = d3.geoDistance([a.lon, a.lat], [s.lon, s.lat]) / deg;
  const dip = clamp(dist / 70) * 0.45 * Math.sin(Math.PI * clamp(p));
  const zoom = Math.exp(lerp(Math.log(a.zoom), Math.log(s.zoom), pz) - dip);
  return { lon: c[0], lat: c[1], zoom };
}
function camera(t) {
  let i = 0;
  while (i + 1 < CAM_KEYS.length && CAM_KEYS[i + 1].t <= t) i++;
  return camAt(i, t);
}

/* ------------------------------------------------------------------ helpers */

function lineAt(t) {
  let idx = -1;
  for (let i = 0; i < TL.lines.length; i++) if (TL.lines[i].start - 0.05 <= t) idx = i;
  return idx;
}
function sceneAt(t) {
  let s = TL.scenes[0];
  for (const sc of TL.scenes) if (sc.start <= t) s = sc;
  return s;
}
function visible(lonlat, cam) {
  return d3.geoDistance(lonlat, [cam.lon, cam.lat]) < 1.48;
}
function place(id) {
  const p = PLACES[id];
  return [p.lon, p.lat];
}

/* ------------------------------------------------------------------ stars / speed lines */

const STARS = [];
const SPEED = [];
function buildBackdrop() {
  const r = rng(11);
  const g = $('#stars');
  for (let i = 0; i < 230; i++) {
    const c = svgEl('circle', { r: (0.6 + r() * 1.6).toFixed(2) });
    g.appendChild(c);
    STARS.push({ el: c, x: r() * 1080, y: r() * 1920, tw: r() * 6.28, sp: 0.5 + r() * 2 });
  }
  const s = $('#speed');
  for (let i = 0; i < 70; i++) {
    const l = svgEl('line', { 'stroke-width': (1 + r() * 2.5).toFixed(1) });
    s.appendChild(l);
    SPEED.push({ el: l, a: r() * Math.PI * 2, r0: 420 + r() * 300, len: 120 + r() * 380, ph: r() });
  }
}
function drawBackdrop(t, cam, speed) {
  const shift = (cam.lon * 2.2) % 1080;
  for (const s of STARS) {
    const x = (((s.x - shift) % 1080) + 1080) % 1080;
    s.el.setAttribute('cx', x.toFixed(1));
    s.el.setAttribute('cy', s.y.toFixed(1));
    s.el.setAttribute('opacity', (0.25 + 0.35 * (0.5 + 0.5 * Math.sin(t * s.sp + s.tw))).toFixed(2));
  }
  const o = clamp((speed - 0.9) / 3.5) * 0.75;
  for (const s of SPEED) {
    if (o <= 0.01) { s.el.setAttribute('opacity', 0); continue; }
    const k = (t * 3 + s.ph) % 1;
    const r0 = s.r0 + k * 260;
    const r1 = r0 + s.len * (0.6 + 0.4 * o);
    const c = Math.cos(s.a), si = Math.sin(s.a);
    s.el.setAttribute('x1', (G.cx + c * r0).toFixed(1));
    s.el.setAttribute('y1', (G.cy + si * r0).toFixed(1));
    s.el.setAttribute('x2', (G.cx + c * r1).toFixed(1));
    s.el.setAttribute('y2', (G.cy + si * r1).toFixed(1));
    s.el.setAttribute('opacity', (o * (1 - k)).toFixed(2));
  }
}

/* ------------------------------------------------------------------ routes / marks / labels */

const ROUTES = [];
function buildRoutes() {
  const g = $('#routes');
  for (const r of EV.routes) {
    const pts = [];
    const cum = [0];
    const stops = r.path.map(place);
    for (let i = 0; i + 1 < stops.length; i++) {
      const interp = d3.geoInterpolate(stops[i], stops[i + 1]);
      const n = Math.max(12, Math.ceil(d3.geoDistance(stops[i], stops[i + 1]) / deg / 1.2));
      for (let j = i === 0 ? 0 : 1; j <= n; j++) pts.push(interp(j / n));
    }
    for (let i = 1; i < pts.length; i++) cum.push(cum[i - 1] + d3.geoDistance(pts[i - 1], pts[i]));
    const pathEl = svgEl('path', { class: `route ${r.style}` });
    const head = svgEl('circle', { class: 'head', r: 9 });
    g.appendChild(pathEl);
    g.appendChild(head);
    ROUTES.push({ ...r, pts, cum, total: cum[cum.length - 1], el: pathEl, head });
  }
}
function routeCoords(r, p) {
  const target = r.total * p;
  const out = [];
  for (let i = 0; i < r.pts.length; i++) {
    if (r.cum[i] <= target) { out.push(r.pts[i]); continue; }
    const seg = r.cum[i] - r.cum[i - 1];
    const f = seg > 0 ? (target - r.cum[i - 1]) / seg : 0;
    out.push(d3.geoInterpolate(r.pts[i - 1], r.pts[i])(f));
    break;
  }
  return out;
}
function glowAllAt() {
  const f = EV.fx.find((x) => x.glowAll);
  return f ? f.t : Infinity;
}
function drawRoutes(t, cam, scene) {
  const tg = glowAllAt();
  for (const r of ROUTES) {
    const p = ease(prog(t, r.t, r.dur));
    if (p <= 0) { r.el.setAttribute('d', ''); r.head.setAttribute('opacity', 0); continue; }
    const coords = routeCoords(r, p);
    r.el.setAttribute('d', coords.length > 1 ? geo({ type: 'LineString', coordinates: coords }) || '' : '');
    let op = r.scene === scene.id ? 1 : 0.5;
    if (t >= tg) op = lerp(0.5, 1, prog(t, tg, 0.8)) * (0.8 + 0.2 * Math.sin((t - tg) * 5));
    r.el.setAttribute('opacity', op.toFixed(2));
    const headPt = coords[coords.length - 1];
    const live = p < 1 ? 1 : 1 - prog(t, r.t + r.dur, 0.4);
    if (live > 0 && visible(headPt, cam)) {
      const [x, y] = proj(headPt);
      r.head.setAttribute('cx', x.toFixed(1));
      r.head.setAttribute('cy', y.toFixed(1));
      r.head.setAttribute('r', (8 + 3 * Math.sin(t * 20)).toFixed(1));
      r.head.setAttribute('opacity', live.toFixed(2));
    } else r.head.setAttribute('opacity', 0);
  }
}

const MARK_ELS = {};
function markTimes() {
  // A place counts as marked when a line marks it or a route reaches it.
  const times = {};
  const add = (id, t, scene, label) => {
    if (!times[id] || times[id].t > t) times[id] = { t, scene, labels: [] };
    if (label) times[id].labels.push({ t, text: label, scene });
  };
  for (const m of EV.marks) add(m.place, m.t, m.scene);
  for (const r of EV.routes) {
    add(r.path[0], r.t, r.scene);
    add(r.path[r.path.length - 1], r.t + r.dur, r.scene, r.labelEnd);
  }
  return times;
}
let MARKS;
function buildMarks() {
  MARKS = markTimes();
  const g = $('#marks');
  const lg = $('#labels');
  for (const id in MARKS) {
    const ring = svgEl('circle', { fill: 'none', stroke: '#f2c56b', 'stroke-width': 3 });
    const dot = svgEl('circle', { fill: '#fff4d6', r: 8 });
    g.appendChild(ring);
    g.appendChild(dot);
    const label = el('div', 'plabel', esc(PLACES[id].label));
    const word = el('div', 'plabel word', '');
    lg.appendChild(label);
    lg.appendChild(word);
    MARK_ELS[id] = { ring, dot, label, word };
  }
}
function placeLabel(node, x, y, opacity, anchor) {
  const left = anchor ? anchor === 'left' : x > 700;
  node.className = node.className.replace(/ (left|right)/g, '') + (left ? ' left' : ' right');
  node.style.left = `${(left ? x - 22 : x + 22).toFixed(1)}px`;
  node.style.top = `${y.toFixed(1)}px`;
  node.style.opacity = opacity.toFixed(2);
}
function drawMarks(t, cam, scene) {
  const outroGlow = t >= glowAllAt();
  for (const id in MARKS) {
    const m = MARKS[id];
    const els = MARK_ELS[id];
    const ll = place(id);
    const on = prog(t, m.t, 0.35);
    if (on <= 0 || !visible(ll, cam)) {
      for (const k in els) els[k].style.opacity = 0;
      continue;
    }
    const [x, y] = proj(ll);
    const current = m.scene === scene.id || MARKS[id].labels.some((l) => l.scene === scene.id);
    els.dot.setAttribute('cx', x.toFixed(1));
    els.dot.setAttribute('cy', y.toFixed(1));
    els.dot.setAttribute('r', (8 * back(on)).toFixed(1));
    els.dot.style.opacity = current || outroGlow ? 1 : 0.55;
    const k = ((t - m.t) % 1.6) / 1.6;
    els.ring.setAttribute('cx', x.toFixed(1));
    els.ring.setAttribute('cy', y.toFixed(1));
    els.ring.setAttribute('r', (10 + 44 * easeOut(k)).toFixed(1));
    els.ring.style.opacity = current ? (0.9 * (1 - k)).toFixed(2) : 0;
    // Place names only for the scene that visits them; word labels for route ends.
    const showName = m.scene === scene.id && scene.id !== 'outro';
    placeLabel(els.label, x, y - 2 + (PLACES[id].dy || 0), showName ? on * (1 - prog(t, scene.end - 0.3, 0.3)) : 0, PLACES[id].anchor);
    const wl = MARKS[id].labels.filter((l) => l.t <= t && l.scene === scene.id).pop();
    if (wl) {
      els.word.textContent = wl.text;
      const wy = showName ? y + 44 : y;
      placeLabel(els.word, x, wy, prog(t, wl.t, 0.3) * (1 - prog(t, scene.end - 0.3, 0.3)));
    } else els.word.style.opacity = 0;
  }
}

/* ------------------------------------------------------------------ globe */

function drawGlobe(t, cam, dim) {
  proj.rotate([-cam.lon, -cam.lat, 0]).scale(G.r * cam.zoom);
  const R = G.r * cam.zoom;
  const og = $('#oceanGrad');
  og.setAttribute('cx', G.cx - R * 0.25);
  og.setAttribute('cy', G.cy - R * 0.3);
  og.setAttribute('r', R * 1.3);
  const ag = $('#atmoGrad');
  ag.setAttribute('cx', G.cx);
  ag.setAttribute('cy', G.cy);
  ag.setAttribute('r', R * 1.08);
  for (const id of ['#ocean', '#atmo']) {
    const c = $(id);
    c.setAttribute('cx', G.cx);
    c.setAttribute('cy', G.cy);
  }
  $('#ocean').setAttribute('r', R);
  $('#atmo').setAttribute('r', R * 1.08);
  $('#atmo').setAttribute('fill', 'url(#atmoGrad)');
  $('#grat').setAttribute('d', geo(GRAT) || '');
  $('#land').setAttribute('d', geo(LAND) || '');
  $('#borders').setAttribute('d', geo(BORDERS) || '');
  $('#globe').setAttribute('opacity', (1 - 0.62 * dim).toFixed(3));
}

/* ------------------------------------------------------------------ header */

let HEADER;
function buildHeader() {
  const h = $('#header');
  $('.s1', h).textContent = TL.series;
  $('.no', h).textContent = `#${TL.number}`;
  $('.word', h).textContent = TL.word;
  $('.ja', h).textContent = TL.wordJa;
  const itin = $('.itin', h);
  itin.appendChild(el('div', 'track'));
  const fill = el('div', 'fill');
  itin.appendChild(fill);
  const n = TL.stops.length;
  const xs = TL.stops.map((_, i) => 40 + (700 * i) / (n - 1));
  const nodes = TL.stops.map((s, i) => {
    const node = el('div', 'node', `<span class="ic">${esc(s.icon)}</span><span class="nm">${esc(s.name)}</span>`);
    node.style.left = `${xs[i]}px`;
    itin.appendChild(node);
    return node;
  });
  const trav = el('div', 'traveler');
  itin.appendChild(trav);
  HEADER = { h, fill, nodes, xs, trav };
}
function eraText(v) {
  if (v >= 2026) return '現在';
  if (v > 0) return `西暦 ${Math.round(v)}年`;
  return `紀元前 ${Math.round(-v)}年`;
}
function eraAt(t) {
  let prev = null, cur = null;
  for (const e of EV.eras) if (e.t <= t) { prev = cur; cur = e; }
  if (!cur) return { text: '', op: 0 };
  if (cur.value === null) {
    const fade = 1 - prog(t, cur.t, 0.3);
    return { text: prev && prev.value !== null ? eraText(prev.value) : '', op: fade };
  }
  const from = prev && prev.value !== null ? prev.value : cur.value;
  const p = ease(prog(t, cur.t, cur.dur));
  let v = lerp(from, cur.value, p);
  if (p < 1 && Math.abs(cur.value - from) > 50) v = Math.round(v / 10) * 10 + (Math.floor(t * 30) % 10);
  const fadeIn = prev && prev.value !== null ? 1 : prog(t, cur.t, 0.3);
  return { text: p >= 1 ? cur.label || eraText(cur.value) : eraText(v), op: fadeIn };
}
function drawHeader(t, scene) {
  const first = TL.scenes[1] ? TL.scenes[1].start : 0;
  const op = prog(t, first + 0.2, 0.5);
  HEADER.h.style.opacity = op.toFixed(2);
  HEADER.h.style.transform = `translateY(${(-30 * (1 - easeOut(op))).toFixed(1)}px)`;
  const idx = TL.stops.findIndex((s) => s.scene === scene.id);
  // scenes after the last stop (answer, outro) show the whole itinerary as done
  const outro = idx < 0 && TL.stops.every((st) => TL.scenes.find((q) => q.id === st.scene).start <= t);
  // traveler glides to the current stop when the scene starts
  let pos = 0;
  for (let i = 0; i < TL.stops.length; i++) {
    const sc = TL.scenes.find((s) => s.id === TL.stops[i].scene);
    if (sc && t >= sc.start) pos = lerp(i === 0 ? 0 : i - 1, i, ease(prog(t, sc.start, 0.8)));
  }
  if (outro) pos = TL.stops.length - 1;
  const x = lerp(HEADER.xs[0], HEADER.xs[HEADER.xs.length - 1], pos / (TL.stops.length - 1));
  HEADER.trav.style.left = `${x}px`;
  HEADER.fill.style.width = `${x - 40}px`;
  HEADER.trav.style.opacity = outro ? 0 : 1;
  HEADER.nodes.forEach((node, i) => {
    const s = TL.stops[i];
    const reached = i < idx || outro || (i === idx);
    node.classList.toggle('done', i < idx || outro);
    node.classList.toggle('now', i === idx && !outro);
    const ic = $('.ic', node);
    ic.textContent = s.reveal && reached ? s.reveal : s.icon;
    const pulse = i === idx && !outro ? 1 + 0.12 * decay(t - (TL.scenes.find((q) => q.id === s.scene).start + 0.8), 0.25) : 1;
    node.style.transform = `scale(${pulse.toFixed(3)})`;
  });
  const stopName = $('.stopname', HEADER.h);
  const label = idx >= 0 ? `STOP ${idx + 1} ｜ ${scene.stop}` : scene.stop || '';
  if (stopName.textContent !== label) stopName.textContent = label;
  const sp = prog(t, scene.start, 0.45);
  stopName.style.opacity = sp.toFixed(2);
  const era = eraAt(t);
  const eraEl = $('.era', HEADER.h);
  eraEl.textContent = era.text;
  eraEl.style.opacity = era.op.toFixed(2);
  eraEl.style.display = era.text ? '' : 'none';
}

/* ------------------------------------------------------------------ subtitles */

const SUBS = [];
function charWeight(ch) {
  if ('「」『』（）()'.includes(ch)) return 0;
  if ('、，,'.includes(ch)) return 2.2;
  if ('。？！?!'.includes(ch)) return 2.6;
  if (ch === ' ') return 0.3;
  if ('ゃゅょっャュョッぁぃぅぇぉ'.includes(ch)) return 0.5;
  if (/[一-鿿]/.test(ch)) return 1.8;
  if (/[぀-ヿ]/.test(ch)) return 1;
  if (/[A-Za-zÀ-ɏḀ-ỿ]/.test(ch)) return 0.55;
  return 0.5;
}
function buildSubtitles() {
  const box = $('#subtitle');
  for (const line of TL.lines) {
    const div = el('div', 'line');
    div.lang = 'ja';
    const chars = [];
    const parts = line.text.split(/(\{[^}]*\})/);
    for (const part of parts) {
      if (!part) continue;
      const kw = part.startsWith('{');
      const text = kw ? part.slice(1, -1) : part;
      const holder = kw ? el('span', 'kw') : div;
      for (const ch of Array.from(text)) {
        const c = el('span', 'c');
        c.textContent = ch;
        holder.appendChild(c);
        chars.push({ el: c, w: charWeight(ch), kw: kw ? holder : null });
      }
      if (kw) div.appendChild(holder);
    }
    let acc = 0;
    const total = chars.reduce((s, c) => s + c.w, 0) || 1;
    for (const c of chars) { c.at = acc / total; acc += c.w; }
    div.style.display = 'none';
    box.appendChild(div);
    SUBS.push({ div, chars });
  }
}
function drawSubtitles(t) {
  const idx = lineAt(t);
  const endCard = EV.cardSets[EV.cardSets.length - 1].t;
  SUBS.forEach((s, i) => {
    const line = TL.lines[i];
    const next = TL.lines[i + 1];
    const until = next ? Math.min(next.start - 0.05, line.end + 0.6) : endCard;
    const show = i === idx && t < until;
    s.div.style.display = show ? '' : 'none';
    if (!show) return;
    const inP = prog(t, line.start - 0.05, 0.14);
    s.div.style.opacity = inP.toFixed(2);
    s.div.style.transform = `translateY(${(14 * (1 - easeOut(inP))).toFixed(1)}px)`;
    const spoken = clamp((t - line.start - 0.06) / Math.max(0.3, line.end - line.start - 0.16));
    const kwStart = new Map();
    for (const c of s.chars) {
      const on = spoken >= c.at;
      c.el.classList.toggle('on', on);
      if (c.kw && !kwStart.has(c.kw)) kwStart.set(c.kw, c.at);
    }
    const dur = line.end - line.start;
    for (const [kw, at] of kwStart) {
      const tk = line.start + 0.06 + at * dur;
      const p = prog(t, tk, 0.22);
      const g = p <= 0 ? 0 : Math.sin(Math.PI * p);
      kw.style.textShadow = g > 0.01 ? `0 0 ${(28 * g).toFixed(1)}px rgba(255, 210, 120, ${(0.95 * g).toFixed(2)})` : '';
    }
  });
}

/* ------------------------------------------------------------------ cards */

const HERO_TYPES = new Set(['pair', 'title', 'end']);
const SETS = [];

function beatsFor(set, nextT) {
  const beats = {};
  if (set.line == null) return beats;
  for (const f of EV.fx) if (f.id && f.t >= set.t - 0.001 && f.t < nextT && !(f.id in beats)) beats[f.id] = f.t;
  return beats;
}
function stateHistory(set, nextT) {
  const hist = [];
  for (const s of EV.cardStates) if (s.t >= set.t - 0.001 && s.t < nextT) hist.push(s);
  return hist;
}
function stateAt(hist, t) {
  const st = {};
  for (const h of hist) if (h.t <= t) Object.assign(st, h.state);
  return st;
}
function firstTime(hist, pred, fallback) {
  const acc = {};
  for (const h of hist) {
    Object.assign(acc, h.state);
    if (pred(acc)) return h.t;
  }
  return fallback;
}

function buildWordCard(c, size) {
  const e = el('div', `panel word ${size}${c.glow ? ' glow' : ''}`);
  e.innerHTML = `
    <div class="meta"><span class="lang">${esc(c.lang)}</span>${c.era ? `<span class="era">${esc(c.era)}</span>` : ''}</div>
    <div class="script f-${c.font}"${c.font === 'hebrew' || c.font === 'arabic' ? ' dir="rtl"' : ''}>${hl(c.script)}</div>
    ${c.sub ? `<div class="sub">${hl(c.sub)}</div>` : ''}
    <div class="gloss">「${esc(c.gloss)}」</div>
    ${c.extra ? `<div class="extra">${esc(c.extra)}</div>` : ''}`;
  return { el: e, update: null };
}

function buildTarget(c) {
  const e = el('div', 'panel target');
  const svg = svgEl('svg', { width: 820, height: 200, viewBox: '0 0 820 200' });
  const tg = svgEl('g', { transform: 'translate(660,128)' });
  [[64, '#f6efe0'], [50, '#d9483f'], [35, '#f6efe0'], [20, '#d9483f'], [7, '#f6efe0']].forEach(([r, f]) => tg.appendChild(svgEl('circle', { r, fill: f, opacity: 0.92 })));
  const stand = svgEl('rect', { x: 654, y: 188, width: 12, height: 12, fill: '#6b5a3a' });
  const arrow = svgEl('g');
  arrow.appendChild(svgEl('line', { x1: -120, y1: 0, x2: 0, y2: 0, stroke: '#e9c47a', 'stroke-width': 6, 'stroke-linecap': 'round' }));
  arrow.appendChild(svgEl('path', { d: 'M 0 0 L -26 -13 L -20 0 L -26 13 Z', fill: '#fff4d6' }));
  arrow.appendChild(svgEl('path', { d: 'M -120 0 L -140 -14 L -104 0 L -140 14 Z', fill: '#d9483f' }));
  const trail = svgEl('path', { fill: 'none', stroke: 'rgba(233,196,122,0.45)', 'stroke-width': 3, 'stroke-dasharray': '6 10' });
  svg.append(stand, tg, trail, arrow);
  e.appendChild(svg);
  e.appendChild(el('div', 'caption', esc(c.caption)));
  const gloss = el('div', 'gloss', `＝「${esc(c.gloss)}」`);
  e.appendChild(gloss);
  const update = (ctx) => {
    const ta = ctx.beats.arrow ?? ctx.t0 + 0.6;
    const p = prog(ctx.t, ta - 0.25, 0.55);
    // flies left -> right, rising slightly: passes just above the target
    const x = lerp(150, 960, easeIn(p) * 0.35 + p * 0.65);
    const y = 74 - 44 * p;
    const ang = Math.atan2(-44, 810) / deg;
    arrow.setAttribute('transform', `translate(${x.toFixed(1)},${y.toFixed(1)}) rotate(${ang.toFixed(1)})`);
    arrow.setAttribute('opacity', p >= 1 ? 0 : 1);
    trail.setAttribute('d', p > 0 ? `M 150 74 L ${x.toFixed(1)} ${y.toFixed(1)}` : '');
    const wob = p >= 0.75 ? Math.sin((ctx.t - ta) * 30) * 4 * decay(ctx.t - ta - 0.2, 0.3) : 0;
    tg.setAttribute('transform', `translate(660,128) rotate(${wob.toFixed(2)})`);
    const gp = prog(ctx.t, ta + 0.1, 0.3);
    gloss.style.opacity = (0.35 + 0.65 * gp).toFixed(2);
    gloss.style.transform = `scale(${(1 + 0.25 * Math.sin(Math.PI * gp)).toFixed(3)})`;
  };
  return { el: e, update };
}

function buildChain(c) {
  const e = el('div', 'panel chain');
  const rows = [];
  c.items.forEach((it, i) => {
    if (i > 0) e.appendChild(el('div', 'arrow', '↓'));
    const row = el('div', 'row', `<span class="w${i === c.items.length - 1 ? ' head' : ''}">${esc(it.w)}</span><span class="note">${esc(it.note)}</span>`);
    e.appendChild(row);
    rows.push(row);
  });
  const update = (ctx) => {
    rows.forEach((row, i) => {
      const t0 = firstTime(ctx.hist, (s) => (s.reveal || 0) >= i + 1, Infinity);
      const prevCount = i === 0 ? 0 : i;
      const stagger = t0 === ctx.t0 ? i * 0.18 : (i - prevCount) * 0.22 + (i >= 2 ? (i - 2) * 0.35 : 0);
      const p = prog(ctx.t, t0 + stagger, 0.35);
      row.style.opacity = p.toFixed(2);
      row.style.transform = `translateX(${(-40 * (1 - easeOut(p))).toFixed(1)}px)`;
    });
  };
  return { el: e, update };
}

function buildShift(c) {
  const e = el('div', 'panel shift');
  const steps = c.steps.map((s, i) => el('span', `step${i === c.steps.length - 1 ? ' last' : ''}`, esc(s)));
  const r1 = el('div', 'rowx');
  const r2 = el('div', 'rowx');
  const arrows = [el('span', 'arr', '→'), el('span', 'arr', '→'), el('span', 'arr', '→')];
  r1.append(steps[0], arrows[0], steps[1]);
  r2.append(arrows[1], steps[2], arrows[2], steps[3]);
  e.append(r1, r2, el('div', 'note', esc(c.note || '')));
  const update = (ctx) => {
    steps.forEach((s, i) => {
      const t0 = firstTime(ctx.hist, (st) => (st.reveal || 0) >= i + 1, Infinity);
      const p = prog(ctx.t, t0 + (i % 2) * 0.35, 0.3);
      s.style.opacity = p.toFixed(2);
      s.style.transform = `scale(${(i === 3 ? lerp(1.8, 1, back(p)) : lerp(0.7, 1, back(p))).toFixed(3)})`;
      if (i > 0) arrows[i - 1].style.opacity = p.toFixed(2);
    });
  };
  return { el: e, update };
}

function buildKanji(c) {
  const e = el('div', 'panel kanji');
  const L = [
    `<div class="cell"><span class="kg">罪</span><span class="lab">つみ</span></div>`,
    `<div class="cell"><span class="kg">辠</span><span class="lab red">もとの字</span></div>`,
    `<div class="cell"><span class="kg">辠</span></div><span class="op">＝</span>
     <div class="cell"><span class="kg s">自</span><span class="lab">鼻</span></div><span class="op">＋</span>
     <div class="cell"><span class="kg s">辛</span><span class="lab">つらさ</span></div>`,
    `<div class="cell"><span class="kg">辠</span><span class="lab">罪（もとの字）</span></div><span class="op">≒</span>
     <div class="cell"><span class="kg">皇</span><span class="lab red">皇帝の「皇」</span></div>`,
    `<div class="cell"><span class="kg">罪</span></div><span class="op">＝</span>
     <div class="cell"><span class="kg s">罒</span><span class="lab">網</span></div><span class="op">＋</span>
     <div class="cell"><span class="kg s">非</span><span class="lab">&nbsp;</span></div>`,
  ].map((html) => {
    const layer = el('div', 'layer', html);
    e.appendChild(layer);
    return layer;
  });
  const rings = [el('div', 'ring'), el('div', 'ring')];
  L[3].append(...rings);
  e.appendChild(el('div', 'src', esc(c.source || '')));
  const update = (ctx) => {
    const st = stateAt(ctx.hist, ctx.t);
    const cur = st.stage || 0;
    const tCur = firstTime(ctx.hist, (s) => (s.stage || 0) === cur, ctx.t0);
    let prev = -1;
    for (const h of ctx.hist) if (h.t < tCur && h.state.stage != null) prev = h.state.stage;
    if (prev === cur) prev = -1;
    const p = prog(ctx.t, tCur, 0.32);
    L.forEach((layer, i) => {
      let op = 0, sc = 1;
      if (i === cur) { op = p; sc = lerp(1.25, 1, back(p)); }
      else if (i === prev) { op = 1 - p; sc = lerp(1, 0.9, p); }
      layer.style.opacity = op.toFixed(2);
      layer.style.transform = `scale(${sc.toFixed(3)})`;
      layer.style.display = op > 0.001 ? '' : 'none';
    });
    if (cur === 3) {
      // circle the look-alike top halves once both glyphs are shown
      const rp = prog(ctx.t, tCur + 0.9, 0.3);
      const glyphs = L[3].querySelectorAll('.kg');
      rings.forEach((r, i) => {
        const g = glyphs[i];
        const x = g.offsetLeft + g.offsetParent.offsetLeft;
        r.style.left = `${x + 20}px`;
        r.style.top = `${g.offsetTop + g.offsetParent.offsetTop - 6}px`;
        r.style.width = `${g.offsetWidth - 40}px`;
        r.style.height = '112px';
        r.style.opacity = rp.toFixed(2);
        r.style.transform = `scale(${lerp(1.4, 1, easeOut(rp)).toFixed(3)})`;
      });
    }
  };
  return { el: e, update };
}

function buildFormula(c) {
  // a glyph equation such as 蜜 ＝ 宓 ＋ 虫, popping in piece by piece
  const e = el('div', 'panel kanji formula');
  const layer = el('div', 'layer');
  const parts = c.items.map((it) => {
    const p = it.op
      ? el('span', 'op', esc(it.op))
      : el('div', 'cell', `<span class="kg${it.s ? ' s' : ''}">${hl(it.g)}</span>${it.lab ? `<span class="lab${it.red ? ' red' : ''}">${esc(it.lab)}</span>` : ''}`);
    layer.appendChild(p);
    return p;
  });
  e.appendChild(layer);
  if (c.title) e.appendChild(el('div', 'ftitle', esc(c.title)));
  if (c.source) e.appendChild(el('div', 'src', esc(c.source)));
  const update = (ctx) => {
    parts.forEach((p, i) => {
      const pp = prog(ctx.t, ctx.t0 + 0.15 + i * 0.16, 0.3);
      p.style.opacity = pp.toFixed(2);
      p.style.transform = `scale(${lerp(1.6, 1, back(pp)).toFixed(3)})`;
    });
  };
  return { el: e, update };
}

function buildTree(c) {
  // one root word fanning out into its descendants; borrowed words hang on dashed lines
  const e = el('div', 'panel tree');
  const W = 940, rootY = 62, rowY = [168, 290];
  const svg = svgEl('svg', { width: W, height: 360, viewBox: `0 0 ${W} 360` });
  e.appendChild(svg);
  const root = el('div', 'root f-latin', hl(c.root));
  root.style.left = `${W / 2}px`;
  root.style.top = `${rootY}px`;
  e.appendChild(root);
  const perRow = Math.ceil(c.leaves.length / 2);
  const leaves = c.leaves.map((lf, i) => {
    const row = Math.floor(i / perRow), col = i % perRow;
    const x = (W / perRow) * (col + 0.5), y = rowY[row];
    const line = svgEl('path', {
      d: `M ${W / 2} ${rootY + 34} C ${W / 2} ${y - 60}, ${x} ${rootY + 60}, ${x} ${y - 34}`,
      class: `tl${lf.borrowed ? ' borrowed' : ''}`,
    });
    svg.appendChild(line);
    const node = el('div', 'leaf', `<div class="lw ${lf.font ? `f-${lf.font}` : 'f-latin'}">${hl(lf.w)}</div><div class="ll">${esc(lf.l)}</div>`);
    node.style.left = `${x}px`;
    node.style.top = `${y}px`;
    e.appendChild(node);
    return { node, line };
  });
  const update = (ctx) => {
    leaves.forEach(({ node, line }, i) => {
      const p = prog(ctx.t, ctx.t0 + 0.25 + i * 0.14, 0.3);
      node.style.opacity = p.toFixed(2);
      node.style.transform = `translate(-50%, -50%) scale(${lerp(0.6, 1, back(p)).toFixed(3)})`;
      line.style.opacity = p.toFixed(2);
    });
    const th = firstTime(ctx.hist, (s) => s.hl, c.lit ? ctx.t0 : Infinity);
    const on = ctx.t >= th;
    const pulse = on ? 1 + 0.35 * decay(ctx.t - th, 0.25) : 1;
    e.querySelectorAll('.hl').forEach((b) => {
      b.classList.toggle('on', on);
      b.style.fontSize = `${(pulse * 100).toFixed(1)}%`;
    });
  };
  return { el: e, update };
}

function buildTable(c) {
  // a sound-correspondence grid, revealed row by row and column by column
  const e = el('div', 'panel stable');
  const grid = el('div', 'grid');
  grid.style.gridTemplateColumns = `minmax(110px, auto) repeat(${c.cols.length}, 1fr)`;
  const cells = [];
  grid.appendChild(el('div', 'th corner', ''));
  c.cols.forEach((h, j) => {
    const d = el('div', 'th', esc(h));
    grid.appendChild(d);
    cells.push({ d, row: -1, col: j });
  });
  c.rows.forEach((r, i) => {
    const k = el('div', 'rk', esc(r.k));
    grid.appendChild(k);
    cells.push({ d: k, row: i, col: -1 });
    r.v.forEach((v, j) => {
      const d = el('div', 'td', hl(v));
      grid.appendChild(d);
      cells.push({ d, row: i, col: j });
    });
  });
  e.appendChild(grid);
  const update = (ctx) => {
    const st = stateAt(ctx.hist, ctx.t);
    const rows = st.rows ?? c.rows.length, cols = st.cols ?? c.cols.length;
    for (const cell of cells) {
      const visible = (cell.row < rows) && (cell.col < cols);
      const tv = firstTime(ctx.hist, (s) => (s.rows ?? c.rows.length) > cell.row && (s.cols ?? c.cols.length) > cell.col, ctx.t0);
      const p = visible ? prog(ctx.t, tv + 0.05 * Math.max(0, cell.col), 0.28) : 0;
      cell.d.style.opacity = p.toFixed(2);
      cell.d.style.transform = `scale(${lerp(0.7, 1, back(p)).toFixed(3)})`;
    }
  };
  return { el: e, update };
}

function buildFork(c) {
  // one word splitting into two roads; state.left / state.right reveal each road step by step
  const e = el('div', 'panel fork');
  const svg = svgEl('svg', { width: 940, height: 370, viewBox: '0 0 940 370' });
  const lineL = svgEl('path', { d: 'M 470 96 C 470 130, 230 100, 230 128', class: 'fl', stroke: '#e9c47a' });
  const lineR = svgEl('path', { d: 'M 470 96 C 470 130, 710 100, 710 128', class: 'fl', stroke: '#e0605a' });
  svg.append(lineL, lineR);
  e.appendChild(svg);
  e.appendChild(el('div', 'froot', `<div class="w">${hl(c.root)}</div><div class="m">${esc(c.rootNote || '')}</div>`));
  const side = (key, def) => {
    const col = el('div', `col ${key === 'left' ? 'l' : 'r'}`);
    const parts = [el('div', 'pill', esc(def.title))];
    def.steps.forEach((s, i) => {
      if (i > 0) parts.push(el('div', 'dn', '↓'));
      parts.push(el('div', 'step', hl(s)));
    });
    const end = el('div', 'end');
    const ends = (def.ends || []).map((g) => el('span', '', `「${esc(g)}」`));
    end.append(...ends);
    col.append(...parts, end);
    e.appendChild(col);
    return { col, parts, ends, def };
  };
  const L = side('left', c.left), R = side('right', c.right);
  const drawSide = (ctx, S, key, line) => {
    const n = stateAt(ctx.hist, ctx.t)[key] || 0;
    const tOf = (k) => firstTime(ctx.hist, (s) => (s[key] || 0) >= k, Infinity);
    const p0 = prog(ctx.t, tOf(1), 0.4);
    line.style.strokeDasharray = '400';
    line.style.strokeDashoffset = (400 * (1 - ease(p0))).toFixed(1);
    // reveal order: pill (1), then each step (2..), then the first ending; later levels swap endings
    let level = 1;
    S.parts.forEach((p) => {
      if (p.className !== 'dn') level += p.className === 'pill' ? 0 : 1;
      const need = p.className === 'pill' ? 1 : p.className === 'dn' ? level + 1 : level;
      const pp = prog(ctx.t, tOf(need), 0.3);
      p.style.opacity = pp.toFixed(2);
      p.style.transform = `translateY(${(16 * (1 - easeOut(pp))).toFixed(1)}px)`;
    });
    const firstEnd = S.def.steps.length + 2;
    S.ends.forEach((sp, j) => {
      const tin = tOf(firstEnd + j), tout = j + 1 < S.ends.length ? tOf(firstEnd + j + 1) : Infinity;
      const pin = prog(ctx.t, tin, 0.3), pout = prog(ctx.t, tout, 0.25);
      sp.style.opacity = (pin * (1 - pout)).toFixed(2);
      sp.style.transform = `scale(${(lerp(1.6, 1, back(pin)) - 0.3 * pout).toFixed(3)})`;
    });
    return n;
  };
  const update = (ctx) => {
    drawSide(ctx, L, 'left', lineL);
    drawSide(ctx, R, 'right', lineR);
    const focus = stateAt(ctx.hist, ctx.t).focus;
    L.col.classList.toggle('dim', focus === 'right');
    R.col.classList.toggle('dim', focus === 'left');
  };
  return { el: e, update };
}

const MERGE_ICONS = {
  shirt: `<svg width="150" height="110" viewBox="0 0 300 220"><path d="M 80 20 L 30 42 L 0 92 L 40 110 L 60 82 L 60 200 L 240 200 L 240 82 L 260 110 L 300 92 L 270 42 L 220 20 Q 150 56 80 20 Z" fill="rgba(233,196,122,0.18)" stroke="#e9c47a" stroke-width="12" stroke-linejoin="round"/></svg>`,
  people: `<svg width="330" height="110" viewBox="0 0 330 110">${[0, 1, 2, 3].map((i) => `<g class="pp"><circle cx="${45 + i * 80}" cy="30" r="17" fill="none" stroke-width="6"/><path d="M ${15 + i * 80} 100 Q ${16 + i * 80} 56 ${45 + i * 80} 54 Q ${74 + i * 80} 56 ${75 + i * 80} 100" fill="none" stroke-width="6" stroke-linecap="round"/></g>`).join('')}</svg>`,
};

function buildMerge(c) {
  // two journeys told earlier (west and east) flowing into one meaning; state.m: 1 left, 2 right, 3 merged
  const e = el('div', 'panel merge');
  const svg = svgEl('svg', { width: 940, height: 800, viewBox: '0 0 940 800' });
  const lineL = svgEl('path', { d: 'M 240 540 C 240 580, 470 560, 470 602', class: 'ml', stroke: '#e9c47a' });
  const lineR = svgEl('path', { d: 'M 700 540 C 700 580, 470 560, 470 602', class: 'ml', stroke: '#e0605a' });
  svg.append(lineL, lineR);
  e.appendChild(svg);
  const side = (key, def) => {
    const col = el('div', `col ${key}`);
    const parts = [el('div', 'pill', esc(def.title))];
    def.rows.forEach(([w, note], i) => {
      if (i > 0) parts.push(el('div', 'dn', '↓'));
      parts.push(el('div', 'row', `<span class="w f-${def.font}">${hl(w)}</span><span class="n">${esc(note)}</span>`));
    });
    const icon = el('div', 'icon', MERGE_ICONS[def.icon]);
    const keyw = el('div', 'key', `「${esc(def.key)}」`);
    parts.push(icon);
    col.append(...parts, keyw);
    e.appendChild(col);
    return { parts, icon, keyw };
  };
  const L = side('l', c.left), R = side('r', c.right);
  const res = el('div', 'res', `<div class="s">${esc(c.result.sub)}</div><div class="w">${esc(c.result.w)}</div>`);
  e.appendChild(res);
  const big = $('.w', res);
  const update = (ctx) => {
    const tOf = (k) => firstTime(ctx.hist, (s) => (s.m || 0) >= k, Infinity);
    const drawSide = (S, t0) => {
      S.parts.forEach((p, i) => {
        const pp = prog(ctx.t, t0 + i * 0.12, 0.3);
        p.style.opacity = pp.toFixed(2);
        p.style.transform = `translateY(${(18 * (1 - easeOut(pp))).toFixed(1)}px)`;
      });
      const tk = t0 + S.parts.length * 0.12 + 0.1;
      const pk = prog(ctx.t, tk, 0.3);
      S.keyw.style.opacity = pk.toFixed(2);
      S.keyw.style.transform = `scale(${(lerp(1.8, 1, back(pk)) + 0.12 * decay(ctx.t - tk - 0.3, 0.25)).toFixed(3)})`;
      return tk;
    };
    drawSide(L, tOf(1));
    const tk = drawSide(R, tOf(2));
    // the little people light up one after another as the flow reaches them
    R.icon.querySelectorAll('.pp').forEach((g, i) => {
      const q = prog(ctx.t, tk + i * 0.18, 0.2);
      g.setAttribute('stroke', q > 0.5 ? '#ffb4ad' : 'rgba(246,239,224,0.45)');
    });
    const t3 = tOf(3);
    const pl = ease(prog(ctx.t, t3, 0.45));
    for (const ln of [lineL, lineR]) {
      ln.style.strokeDasharray = '320';
      ln.style.strokeDashoffset = (320 * (1 - pl)).toFixed(1);
    }
    const ps = prog(ctx.t, t3 + 0.2, 0.3);
    $('.s', res).style.opacity = ps.toFixed(2);
    const pb = prog(ctx.t, t3 + 0.4, 0.3);
    big.style.opacity = pb.toFixed(2);
    big.style.transform = `scale(${(lerp(2.2, 1, easeOut(pb)) + 0.1 * decay(ctx.t - t3 - 0.7, 0.3)).toFixed(3)})`;
    e.classList.toggle('glow', ctx.t >= t3 + 0.4);
  };
  return { el: e, update };
}

function buildArt(c) {
  // an animated line illustration from art.js, with an optional caption
  const e = el('div', 'panel art');
  const def = ART[c.art];
  const svg = svgEl('svg', { width: 940, height: 300, viewBox: '0 0 940 300' });
  svg.innerHTML = def.svg;
  e.appendChild(svg);
  if (def.init) def.init(svg);
  if (c.caption) e.appendChild(el('div', 'acap', hl(c.caption)));
  const update = (ctx) => def.update(svg, ctx.t - ctx.t0);
  return { el: e, update };
}

function buildImage(c) {
  // museum photos in a frame, slowly drifting (Ken Burns), with captions and an optional quote
  const w = el('div', `imgset n${c.items.length}`);
  const figs = c.items.map((it, i) => {
    const img = TL.images[it.img];
    const f = el('figure', 'fig', `<div class="frame"><img src="${img.src}"></div><figcaption>${hl(it.caption || '')}</figcaption>`);
    if (it.tag) f.appendChild(el('div', 'ftag', hl(it.tag)));
    w.appendChild(f);
    return f;
  });
  let quote = null;
  if (c.quote) {
    quote = el('div', 'quote', `<div class="q f-greek">${hl(c.quote.text)}</div><div class="tr">${esc(c.quote.tr)}</div>`);
    w.appendChild(quote);
  }
  let badge = null;
  if (c.badge) {
    badge = el('div', 'ibadge', hl(c.badge));
    w.appendChild(badge);
  }
  const update = (ctx) => {
    const lt = ctx.t - ctx.t0;
    figs.forEach((f, i) => {
      const p = prog(ctx.t, ctx.t0 + i * 0.35, 0.45);
      f.style.opacity = p.toFixed(2);
      f.style.transform = `translateY(${(40 * (1 - easeOut(p))).toFixed(1)}px)`;
      const img = f.querySelector('img');
      img.style.transform = `scale(${(1.02 + 0.012 * lt).toFixed(4)})`;
    });
    if (quote) {
      const q = prog(ctx.t, ctx.t0 + 0.9, 0.4);
      quote.style.opacity = q.toFixed(2);
      quote.style.transform = `translateY(${(20 * (1 - easeOut(q))).toFixed(1)}px)`;
    }
    if (badge) {
      const b = prog(ctx.t, ctx.t0 + (ctx.beats.badge ? ctx.beats.badge - ctx.t0 : 0.8), 0.3);
      badge.style.opacity = b.toFixed(2);
      badge.style.transform = `rotate(-6deg) scale(${lerp(1.8, 1, back(b)).toFixed(3)})`;
    }
  };
  return { el: w, update };
}

function buildWall(c) {
  // many words for the same thing popping up all over the screen
  const dense = c.words.length > 8;
  const w = el('div', dense ? 'wall dense' : 'wall');
  const r = rng(7);
  const items = c.words.map((it, i) => {
    const node = el('div', 'wword', `<div class="ww ${it.font ? `f-${it.font}` : 'f-latin'}"${it.size ? ` style="font-size:${it.size}px"` : ''}>${hl(it.w)}</div><div class="wl">${esc(it.l)}</div>`);
    if (dense) {
      const col = i % 3, row = Math.floor(i / 3);
      node.style.left = `${[200, 540, 880][col] + (r() - 0.5) * 60}px`;
      node.style.top = `${530 + row * 160 + (col === 1 ? 60 : 0)}px`;
    } else {
      const col = i % 2, row = Math.floor(i / 2);
      node.style.left = `${(col ? 770 : 310) + (r() - 0.5) * 140}px`;
      node.style.top = `${330 + row * 150 + (col ? 70 : 0)}px`;
    }
    w.appendChild(node);
    return { node, rot: (r() - 0.5) * 10 };
  });
  const update = (ctx) => {
    const span = (ctx.beats.done ?? ctx.t0 + 2.4) - ctx.t0;
    items.forEach(({ node, rot }, i) => {
      // keep long words fully on screen
      if (!node.dataset.x) node.dataset.x = parseFloat(node.style.left);
      const half = node.offsetWidth / 2 + 24;
      node.style.left = `${clamp(parseFloat(node.dataset.x), half, 1080 - half)}px`;
      const p = prog(ctx.t, ctx.t0 + (span * i) / items.length, 0.22);
      node.style.opacity = p.toFixed(2);
      node.style.transform = `translate(-50%, -50%) rotate(${rot.toFixed(1)}deg) scale(${lerp(2.2, 1, easeOut(p)).toFixed(3)})`;
    });
    const th = ctx.beats.hl ?? Infinity;
    w.querySelectorAll('.hl').forEach((b) => b.classList.toggle('on', ctx.t >= th));
  };
  return { el: w, update };
}

function buildTriad(c) {
  const e = el('div', 'panel triad');
  const cols = [];
  c.items.forEach((it, i) => {
    if (i > 0) e.appendChild(el('div', 'sep'));
    const col = el('div', 'col', `<div class="k">${esc(it.k)}</div><div class="from">${esc(it.from)}</div>`);
    e.appendChild(col);
    cols.push(col);
  });
  const update = (ctx) => {
    cols.forEach((col, i) => {
      const t0 = firstTime(ctx.hist, (s) => (s.reveal || 0) >= i + 1, Infinity);
      const p = prog(ctx.t, t0, 0.4);
      col.style.opacity = p.toFixed(2);
      col.style.transform = `translateY(${(26 * (1 - easeOut(p))).toFixed(1)}px)`;
    });
  };
  return { el: e, update };
}

function buildPair(c, isEnd) {
  const w = el('div', 'pairwrap');
  const a = el('div', 'g a', esc(c.a));
  const b = el('div', 'g b', esc(c.b));
  const rays = el('div', 'rays');
  const svg = svgEl('svg', { width: 1080, height: 600, viewBox: '0 0 1080 600' });
  const arc = svgEl('path', { d: 'M 250 410 Q 540 560 800 410', fill: 'none', stroke: '#e9c47a', 'stroke-width': 7, 'stroke-linecap': 'round' });
  svg.appendChild(arc);
  const len = 640;
  arc.setAttribute('stroke-dasharray', `${len}`);
  const bond = el('div', 'bond', esc(c.bond));
  w.append(rays, svg, a, b, bond);
  const update = (ctx) => {
    const tb0 = isEnd ? ctx.t0 : ctx.beats.a ?? ctx.t0;
    const ta = isEnd ? ctx.t0 : 0; // the very first frame already shows 罪
    const pa = isEnd ? prog(ctx.t, ta, 0.35) : 1;
    const punchA = isEnd ? 0 : 0.28 * decay(ctx.t - tb0, 0.12);
    const tb = isEnd ? ctx.t0 + 0.25 : ctx.beats.b ?? ctx.t0 + 0.6;
    const pb = prog(ctx.t, tb, 0.22);
    const slide = isEnd ? 0 : 290 * (1 - ease(prog(ctx.t, tb - 0.12, 0.25)));
    a.style.opacity = pa.toFixed(2);
    a.style.transform = `translateX(${slide.toFixed(1)}px) scale(${(lerp(1.5, 1, back(pa)) + punchA + (isEnd ? 0 : 0.35 * slide / 290)).toFixed(3)})`;
    b.style.opacity = pb.toFixed(2);
    b.style.transform = `scale(${lerp(2.2, 1, easeOut(pb)).toFixed(3)})`;
    const tbond = isEnd ? ctx.t0 + 0.55 : ctx.beats.bond ?? ctx.t0 + 1.2;
    const pk = prog(ctx.t, tbond, 0.35);
    arc.setAttribute('stroke-dashoffset', (len * (1 - ease(pk))).toFixed(1));
    bond.style.opacity = pk.toFixed(2);
    bond.style.transform = `scale(${lerp(0.4, 1, back(pk)).toFixed(3)})`;
    rays.style.opacity = (0.9 * pk).toFixed(2);
    rays.style.transform = `rotate(${((ctx.t - tbond) * 22).toFixed(1)}deg) scale(${lerp(0.5, 1, easeOut(pk)).toFixed(3)})`;
  };
  return { el: w, update };
}

function buildTitle(c) {
  const w = el('div', 'titlewrap', `<div class="t">${esc(c.word)}</div><div class="j">${esc(c.ja)}</div><div class="rule"></div><div class="s">${esc(TL.series)}　#${TL.number}</div>`);
  const t = $('.t', w);
  const update = (ctx) => {
    const p = prog(ctx.t, ctx.t0, 0.3);
    t.style.transform = `scale(${lerp(1.6, 1, easeOut(p)).toFixed(3)})`;
    t.style.letterSpacing = `${lerp(0.3, 0.02, easeOut(p)).toFixed(3)}em`;
    t.style.filter = `blur(${(10 * (1 - p)).toFixed(1)}px)`;
  };
  return { el: w, update };
}

function buildEndQuote(c) {
  // closing line as the last image: a big glyph with sound rings and the sentence under it
  const w = el('div', 'endwrap endq');
  const glyph = el('div', 'eg', esc(c.glyph || ''));
  const rings = el('div', 'rings', '<i></i><i></i><i></i>');
  const quote = el('div', 'eq', hl(c.quote));
  const credit = TL.engine === 'openjtalk' ? '仮音声：Open JTalk' : `VOICEVOX:${TL.voice.name}`;
  const [q, rest] = (TL.cta || '').split(/(?<=？)\s*/);
  const cta = el('div', 'cta', `<b>${esc(q || '')}</b><br>${esc(rest || '')}`);
  const cr = el('div', 'credit', esc(credit));
  w.append(rings, glyph, quote, cta, cr);
  const update = (ctx) => {
    const lt = ctx.t - ctx.t0;
    const g = prog(ctx.t, ctx.t0, 0.5);
    glyph.style.opacity = g.toFixed(2);
    glyph.style.transform = `scale(${lerp(1.5, 1, back(g)).toFixed(3)})`;
    rings.querySelectorAll('i').forEach((r, i) => {
      const k = ((lt - 0.4 - i * 0.5) % 1.5 + 1.5) % 1.5 / 1.5;
      r.style.opacity = lt < 0.4 + i * 0.5 ? 0 : (0.8 * (1 - k)).toFixed(2);
      r.style.transform = `translate(-50%, -50%) scale(${(0.6 + 0.9 * k).toFixed(3)})`;
    });
    const qp = prog(ctx.t, ctx.t0 + 0.4, 0.6);
    quote.style.opacity = qp.toFixed(2);
    quote.style.transform = `translateY(${(24 * (1 - easeOut(qp))).toFixed(1)}px)`;
    const p = prog(ctx.t, ctx.t0 + 2.2, 0.5);
    cta.style.opacity = p.toFixed(2);
    cr.style.opacity = prog(ctx.t, ctx.t0 + 2.5, 0.5).toFixed(2);
  };
  return { el: w, update };
}

function buildEnd() {
  if (TL.cards.end && TL.cards.end.quote) return buildEndQuote(TL.cards.end);
  const w = el('div', 'endwrap');
  const pair = buildPair(TL.cards.pair, true);
  const credit = TL.engine === 'openjtalk' ? '仮音声：Open JTalk' : `VOICEVOX:${TL.voice.name}`;
  const [q, rest] = (TL.cta || '').split(/(?<=？)\s*/);
  const cta = el('div', 'cta', `<b>${esc(q || '')}</b><br>${esc(rest || '')}`);
  const cr = el('div', 'credit', esc(credit));
  w.append(pair.el, cta, cr);
  const update = (ctx) => {
    pair.update(ctx);
    const p = prog(ctx.t, ctx.t0 + 0.9, 0.5);
    cta.style.opacity = p.toFixed(2);
    cta.style.transform = `translateY(${(20 * (1 - easeOut(p))).toFixed(1)}px)`;
    cr.style.opacity = prog(ctx.t, ctx.t0 + 1.2, 0.5).toFixed(2);
  };
  return { el: w, update };
}

function buildSet(i) {
  const set = EV.cardSets[i];
  const defs = set.cards.map((id) => ({ id, ...TL.cards[id] }));
  const hero = defs.length === 1 && (HERO_TYPES.has(defs[0].type) || defs[0].hero || defs[0].type === 'wall' || defs[0].type === 'image');
  const box = el('div', `set${hero ? ' hero' : ''}`);
  const parts = defs.map((c) => {
    switch (c.type) {
      case 'word': return buildWordCard(c, defs.length === 1 ? 'single' : defs.length === 2 ? 'double' : 'quad');
      case 'target': return buildTarget(c);
      case 'chain': return buildChain(c);
      case 'shift': return buildShift(c);
      case 'kanji': return buildKanji(c);
      case 'formula': return buildFormula(c);
      case 'tree': return buildTree(c);
      case 'wall': return buildWall(c);
      case 'fork': return buildFork(c);
      case 'merge': return buildMerge(c);
      case 'art': return buildArt(c);
      case 'image': return buildImage(c);
      case 'table': return buildTable(c);
      case 'triad': return buildTriad(c);
      case 'pair': return buildPair(c, false);
      case 'title': return buildTitle(c);
      case 'end': return buildEnd();
      default: return { el: el('div'), update: null };
    }
  });
  parts.forEach((p) => box.appendChild(p.el));
  (hero ? $('#hero') : $('#cards')).appendChild(box);
  box.style.display = 'none';
  let nextT = EV.cardSets[i + 1] ? EV.cardSets[i + 1].t : Infinity;
  // cards normally leave with their scene; "persist" cards (like a fork that the next stop continues) stay
  if (set.line != null && !defs.some((d) => d.persist)) {
    const sc = TL.scenes.find((s) => s.id === TL.lines[set.line].scene);
    nextT = Math.min(nextT, sc.end - 0.1);
  }
  return { set, box, parts, hero, beats: beatsFor(set, nextT), hist: stateHistory(set, nextT), nextT };
}

function drawCards(t) {
  let cur = -1;
  for (let i = 0; i < EV.cardSets.length; i++) if (EV.cardSets[i].t <= t) cur = i;
  let heroAmt = 0;
  SETS.forEach((S, i) => {
    const enter = prog(t, S.set.t, S.hero ? 0.3 : 0.42);
    const exit = prog(t, S.nextT, S.hero ? 0.35 : 0.28);
    const active = i === cur || (i === cur - 1 && exit < 1);
    S.box.style.display = active && S.parts.length ? '' : 'none';
    if (!active) return;
    // a hero card that has already left (its scene ended) must not keep the globe dimmed
    if (S.hero) heroAmt = Math.max(heroAmt, Math.min(enter, 1 - exit));
    const ctx = { t, t0: S.set.t, beats: S.beats, hist: S.hist };
    S.parts.forEach((p, k) => {
      const pe = S.hero ? enter : prog(t, S.set.t + k * 0.1, 0.42);
      let op = pe * (1 - exit);
      let tf;
      if (S.hero) tf = `scale(${lerp(1, 1.12, easeIn(exit)).toFixed(3)})`;
      else tf = `translateY(${(50 * (1 - easeOut(pe)) - 40 * easeIn(exit)).toFixed(1)}px) scale(${lerp(0.9, 1, back(pe)).toFixed(3)})`;
      // the first hook frame must already be fully visible (thumbnail)
      if (S.hero && S.set.t === 0) op = 1 - exit;
      p.el.style.opacity = op.toFixed(3);
      p.el.style.transform = tf;
      if (p.update) p.update(ctx);
    });
  });
  return heroAmt;
}

/* ------------------------------------------------------------------ fx */

const FXEL = [];
function buildFx() {
  const layer = $('#fxlayer');
  for (const f of EV.fx) {
    const item = { f, parts: [] };
    if (f.montage) {
      const r = rng(Math.round(f.t * 1000));
      const fonts = { latin: '"Noto Serif"', hebrew: '"Noto Serif Hebrew"', deva: '"Noto Serif Devanagari"', cjk: '"Shippori Mincho"', kr: '"Noto Serif KR"', arabic: '"Noto Naskh Arabic"' };
      item.montage = f.montage.map((w, i) => {
        const kind = /[֐-׿]/.test(w) ? 'hebrew' : /[ऀ-ॿ]/.test(w) ? 'deva' : /[一-鿿]/.test(w) ? 'cjk' : /[가-힯]/.test(w) ? 'kr' : /[؀-ۿ]/.test(w) ? 'arabic' : 'latin';
        const e = el('div', 'montage', esc(w));
        e.style.fontFamily = fonts[kind];
        e.style.fontSize = `${Math.round(kind === 'cjk' ? 150 : 96 + r() * 40)}px`;
        e.style.left = `${Math.round(540 + (r() - 0.5) * 360)}px`;
        e.style.translate = '-50% 0';
        e.style.top = `${Math.round((i % 2 ? 810 : 300) + r() * 150)}px`;
        e.style.opacity = 0;
        layer.appendChild(e);
        return { e, rot: (r() - 0.5) * 16 };
      });
    }
    if (f.counter) {
      const e = el('div', 'counter', `<span class="n">0</span><span class="u">${esc(f.counter.suffix || '')}</span>`);
      e.style.opacity = 0;
      layer.appendChild(e);
      item.counter = e;
    }
    if (f.stamp) {
      const e = el('div', 'stamp', esc(f.stamp));
      e.style.left = `${(f.stampPos || [800, 1100])[0]}px`;
      e.style.top = `${(f.stampPos || [800, 1100])[1]}px`;
      e.style.opacity = 0;
      layer.appendChild(e);
      item.stamp = e;
    }
    if (f.pop) {
      const e = el('div', 'popword', `<span class="p">${esc(f.pop)}</span>`);
      e.style.top = '560px';
      e.style.opacity = 0;
      layer.appendChild(e);
      item.pop = e;
    }
    FXEL.push(item);
  }
}
function drawFx(t) {
  let flash = 0, flashColor = '#ffffff', shake = 0, punch = 0, dim = 0, hide = 0;
  for (const item of FXEL) {
    const f = item.f;
    const dt = t - f.t;
    const line = f.line != null ? TL.lines[f.line] : null;
    const lineEnd = line ? line.end : f.t + 1;
    if (f.flash && dt >= 0) {
      const v = f.flash * decay(dt, 0.11);
      if (v > flash) { flash = v; flashColor = f.flashColor || '#ffffff'; }
    }
    if (f.shake) shake += f.shake * decay(dt, 0.16);
    if (f.punch) punch += f.punch * decay(dt, 0.14);
    if (item.montage) {
      const on = t >= f.t && t < f.t + f.dur;
      const per = 0.12;
      const k = Math.floor((t - f.t) / per);
      item.montage.forEach((m, i) => {
        const vis = on && k % item.montage.length === i;
        const local = ((t - f.t) % per) / per;
        m.e.style.opacity = vis ? (1 - 0.5 * local).toFixed(2) : 0;
        const jitter = vis ? Math.sin(t * 90 + i) * 6 : 0;
        m.e.style.transform = `translate(${jitter.toFixed(1)}px,0) rotate(${m.rot.toFixed(1)}deg) scale(${(1.15 - 0.15 * local).toFixed(3)})`;
      });
      if (on) dim = Math.max(dim, 1);
      else if (dt >= 0) dim = Math.max(dim, 1 - prog(t, f.t + f.dur, 0.3));
    }
    if (item.counter) {
      const p = prog(t, f.t, f.dur);
      const v = Math.round(lerp(f.counter.from, f.counter.to, easeOut(p)));
      $('.n', item.counter).textContent = v.toLocaleString('en-US');
      const vis = dt >= 0 && t < lineEnd + 0.1;
      item.counter.style.opacity = vis ? (1 - prog(t, lineEnd - 0.15, 0.2)).toFixed(2) : 0;
      const lock = decay(t - (f.t + f.dur), 0.15);
      item.counter.style.transform = `scale(${(1 + (p >= 1 ? 0.18 * lock : 0.03 * Math.sin(t * 60))).toFixed(3)})`;
    }
    if (item.stamp) {
      const p = prog(t, f.t - 0.12, 0.12);
      const out = prog(t, f.t + 1.6, 0.35);
      item.stamp.style.opacity = dt >= -0.12 ? (Math.min(1, p * 1.5) * (1 - out)).toFixed(2) : 0;
      item.stamp.style.transform = `rotate(-11deg) scale(${lerp(2.8, 1, easeIn(p)).toFixed(3)})`;
    }
    if (item.pop) {
      const p = prog(t, f.t, 0.35);
      const out = prog(t, f.t + 1.25, 0.3);
      item.pop.style.opacity = dt >= 0 ? (p * (1 - out)).toFixed(2) : 0;
      item.pop.style.transform = `scale(${(lerp(0.3, 1, back(p)) + 0.2 * easeIn(out)).toFixed(3)})`;
      if (dt >= 0 && out < 1) { dim = Math.max(dim, 0.6 * p * (1 - out)); hide = Math.max(hide, p * (1 - out)); }
    }
  }
  const fl = $('#flash');
  fl.style.opacity = clamp(flash).toFixed(3);
  fl.style.background = flashColor;
  const sx = shake * (Math.sin(t * 71.3) * 0.6 + Math.sin(t * 43.7) * 0.4);
  const sy = shake * (Math.cos(t * 67.1) * 0.6 + Math.sin(t * 37.9) * 0.4);
  $('#shaker').style.transform = `translate(${sx.toFixed(1)}px,${sy.toFixed(1)}px) scale(${(1 + punch).toFixed(4)})`;
  return { dim, hide: Math.max(dim, hide) };
}

/* ------------------------------------------------------------------ frame */

let lastCam = null;
window.renderFrame = function renderFrame(t) {
  const scene = sceneAt(t);
  const cam = camera(t);
  const prev = camera(Math.max(0, t - 1 / 30));
  const speed = d3.geoDistance([cam.lon, cam.lat], [prev.lon, prev.lat]) / deg * 30 / 10 + Math.abs(Math.log(cam.zoom / prev.zoom)) * 30 * 1.5;
  const heroAmt = drawCards(t);
  const fx = drawFx(t);
  drawGlobe(t, cam, Math.max(heroAmt, fx.dim));
  drawBackdrop(t, cam, speed);
  drawRoutes(t, cam, scene);
  drawMarks(t, cam, scene);
  $('#labels').style.opacity = (1 - Math.max(heroAmt, fx.hide)).toFixed(2);
  drawHeader(t, scene);
  drawSubtitles(t);
  lastCam = cam;
};

/* ------------------------------------------------------------------ init */

function allText() {
  const bits = [TL.series, TL.word, TL.wordJa, TL.cta || '', '0123456789,年前西暦紀元現在STOP｜ ↓→＝＋≒✓？'];
  for (const l of TL.lines) bits.push(l.text);
  for (const s of TL.scenes) bits.push(s.stop || '');
  for (const s of TL.stops) bits.push(s.icon + s.name + (s.reveal || ''));
  for (const id in TL.places) bits.push(TL.places[id].label);
  bits.push(JSON.stringify(TL.cards));
  for (const f of EV.fx) bits.push(JSON.stringify(f));
  for (const r of EV.routes) bits.push(r.labelEnd || '');
  bits.push('つみもとの字鼻つらさ罪（もとの字）皇帝の「皇」網罒非自辛辠皇出典仮音声：Open JTalk VOICEVOX:' + TL.voice.name);
  return bits.join('');
}

window.ready = (async function init() {
  const params = new URLSearchParams(location.search);
  TL = await (await fetch(params.get('timeline'))).json();
  EV = TL.events;
  PLACES = TL.places;
  const landTopo = await (await fetch('../node_modules/world-atlas/land-50m.json')).json();
  const countries = await (await fetch('../node_modules/world-atlas/countries-50m.json')).json();
  LAND = topojson.feature(landTopo, landTopo.objects.land);
  BORDERS = topojson.mesh(countries, countries.objects.countries, (a, b) => a !== b);
  CAM_KEYS = EV.camera.map((k) => ({ ...k }));
  if (TL.engine === 'openjtalk') {
    $('#tag').textContent = 'PREVIEW｜仮音声';
    $('#tag').style.display = 'block';
  }
  buildBackdrop();
  buildRoutes();
  buildMarks();
  buildHeader();
  buildSubtitles();
  for (let i = 0; i < EV.cardSets.length; i++) SETS.push(buildSet(i));
  buildFx();
  const text = allText();
  const specs = [
    '500 40px "Shippori Mincho"', '700 40px "Shippori Mincho"', '800 40px "Shippori Mincho"', '700 40px "Noto Serif JP"',
    '400 40px "Noto Serif"', 'italic 400 40px "Noto Serif"', '600 40px "Noto Serif"', 'italic 600 40px "Noto Serif"',
    '600 40px "Noto Serif Hebrew"', '600 40px "Noto Serif Devanagari"', '600 40px "Noto Serif KR"', '600 40px "Noto Naskh Arabic"',
    '600 40px "Cormorant Garamond"', 'italic 600 40px "Cormorant Garamond"', '700 40px "Cormorant Garamond"',
  ];
  await Promise.all(specs.map((s) => document.fonts.load(s, text)));
  await document.fonts.ready;
  window.renderFrame(0);
  return { duration: TL.duration, fps: TL.fps || 30 };
})();
