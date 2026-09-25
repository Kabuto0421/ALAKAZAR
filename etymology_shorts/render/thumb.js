'use strict';
// Thumbnail page: thumb.html?episode=/episodes/sin.json&id=a
// Big type over the same globe as the video, sized to read at phone-grid size.

const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;');
// "{…}" marks the gold part of a line
const rich = (s) => esc(s).replace(/\{([^}]*)\}/g, '<em>$1</em>');
const NS = 'http://www.w3.org/2000/svg';

function text(cls, html, top) {
  const e = document.createElement('div');
  e.className = `t ${cls}`;
  e.innerHTML = html;
  e.style.top = `${top}px`;
  return e;
}

function targetIcon() {
  // an arrow sailing over the top of a target: "missing the mark"
  const svg = document.createElementNS(NS, 'svg');
  svg.setAttribute('width', 1080);
  svg.setAttribute('height', 520);
  svg.style.position = 'absolute';
  svg.style.left = '0';
  svg.style.top = '420px';
  svg.innerHTML = `
    <g transform="translate(700,300)">
      <circle r="190" fill="#f6efe0"/><circle r="148" fill="#d9483f"/><circle r="104" fill="#f6efe0"/>
      <circle r="60" fill="#d9483f"/><circle r="20" fill="#f6efe0"/>
    </g>
    <path d="M 60 190 L 980 40" stroke="rgba(255,210,122,0.55)" stroke-width="8" stroke-dasharray="14 18" fill="none"/>
    <g transform="translate(1000,36) rotate(-9)">
      <line x1="-300" y1="0" x2="0" y2="0" stroke="#ffd27a" stroke-width="18" stroke-linecap="round"/>
      <path d="M 0 0 L -64 -32 L -48 0 L -64 32 Z" fill="#fff6df"/>
      <path d="M -300 0 L -350 -34 L -262 0 L -350 34 Z" fill="#e0403a"/>
    </g>`;
  return svg;
}

const LAYOUTS = {
  equation(t, box) {
    const eq = document.createElement('div');
    eq.className = 'eqbars';
    eq.innerHTML = '<i></i><i></i>';
    box.append(
      text('kicker', rich(t.kicker), 150),
      text('gA', esc(t.a), 270),
      eq,
      text('gB', esc(t.b), 965),
      text('tail', rich(t.tail.join('')), 1360),
    );
  },
  kanji(t, box) {
    const slash = document.createElement('div');
    slash.className = 'slash';
    box.append(
      text('kicker', rich(t.kicker), 150),
      text('headline', rich(t.headline), 290),
      text('glyph', esc(t.glyph), 500),
      slash,
      text('tail', rich(t.tail.join('')), 1370),
    );
  },
  target(t, box) {
    box.append(
      text('kicker', rich(t.kicker), 170),
      targetIcon(),
      text('big', rich(t.headline), 950),
      text('tail', rich(t.tail.join('')), 1340),
    );
  },
};

function drawGlobe(ep, focus) {
  const svg = document.querySelector('svg.globe');
  const proj = d3.geoOrthographic().clipAngle(90).translate([540, 960]).scale(900).rotate([-focus[0], -focus[1]]);
  const path = d3.geoPath(proj);
  const add = (d, cls) => {
    const p = document.createElementNS(NS, 'path');
    p.setAttribute('d', d || '');
    p.setAttribute('class', cls);
    svg.appendChild(p);
  };
  add(path({ type: 'Sphere' }), 'grat');
  add(path(d3.geoGraticule10()), 'grat');
  add(path(window.LAND), 'land');
  const at = (id) => [ep.places[id].lon, ep.places[id].lat];
  for (const sc of ep.scenes) {
    for (const line of sc.lines) {
      for (const r of line.routes || []) {
        add(path({ type: 'LineString', coordinates: r.path.map(at) }), `route ${r.style}`);
      }
    }
  }
  for (const id in ep.places) {
    const [x, y] = proj(at(id));
    if (d3.geoDistance(at(id), focus) > 1.45) continue;
    const c = document.createElementNS(NS, 'circle');
    c.setAttribute('cx', x);
    c.setAttribute('cy', y);
    c.setAttribute('r', 12);
    c.setAttribute('class', 'dot');
    svg.appendChild(c);
  }
  svg.style.filter = 'drop-shadow(0 0 14px rgba(245, 200, 106, 0.55))';
}

window.ready = (async () => {
  const q = new URLSearchParams(location.search);
  const ep = await (await fetch(q.get('episode'))).json();
  const t = ep.thumbnails.find((x) => x.id === q.get('id')) || ep.thumbnails[0];
  const topo = await (await fetch('../node_modules/world-atlas/land-110m.json')).json();
  window.LAND = topojson.feature(topo, topo.objects.land);
  drawGlobe(ep, t.focus);
  const box = document.getElementById('content');
  const badge = document.createElement('div');
  badge.className = 'badge';
  badge.textContent = `${ep.series} #${ep.number}`;
  box.appendChild(badge);
  LAYOUTS[t.layout](t, box);
  document.querySelector('.rays').style.display = t.layout === 'kanji' ? 'none' : '';
  await document.fonts.load('800 100px "Shippori Mincho"', box.textContent + '＝？');
  await document.fonts.ready;
  return t.id;
})();
