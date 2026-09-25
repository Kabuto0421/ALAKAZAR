'use strict';
// Small animated line-art illustrations for "art" cards. Each entry returns
// { svg: markup, update(lt) } where lt is seconds since the card appeared.
// Drawn on a 940×300 canvas in the same gold/cream/cyan/red palette as the cards.

const INK = { gold: '#e9c47a', cream: '#f6efe0', cyan: '#9fd8ec', red: '#e0605a', dim: 'rgba(246,239,224,0.35)' };

function waveArcs(cx, cy, dir, n, r0, gap, cls) {
  // n concentric arcs opening toward dir ('up', 'right', 'left')
  let out = '';
  for (let i = 0; i < n; i++) {
    const r = r0 + i * gap;
    let d;
    if (dir === 'up') d = `M ${cx - r} ${cy} A ${r} ${r} 0 0 1 ${cx + r} ${cy}`;
    else if (dir === 'right') d = `M ${cx} ${cy - r} A ${r} ${r} 0 0 1 ${cx} ${cy + r}`;
    else d = `M ${cx} ${cy - r} A ${r} ${r} 0 0 0 ${cx} ${cy + r}`;
    out += `<path class="${cls} a${i}" d="${d}" fill="none" stroke-width="6" stroke-linecap="round"/>`;
  }
  return out;
}

function vessel(cx, cy, color) {
  // the "sai" prayer vessel: a U-shaped box under a lid bar
  return `<g class="vessel">
    <path d="M ${cx - 95} ${cy - 48} L ${cx + 95} ${cy - 48}" stroke="${color}" stroke-width="9" stroke-linecap="round"/>
    <path d="M ${cx - 70} ${cy - 48} L ${cx - 70} ${cy + 45} L ${cx + 70} ${cy + 45} L ${cx + 70} ${cy - 48}" fill="rgba(159,216,236,0.08)" stroke="${color}" stroke-width="9" stroke-linejoin="round"/>
  </g>`;
}

function person(cx, cy, color) {
  return `<g><circle cx="${cx}" cy="${cy - 46}" r="26" fill="none" stroke="${color}" stroke-width="7"/>
    <path d="M ${cx - 46} ${cy + 50} Q ${cx - 44} ${cy - 8} ${cx} ${cy - 10} Q ${cx + 44} ${cy - 8} ${cx + 46} ${cy + 50}" fill="none" stroke="${color}" stroke-width="7" stroke-linecap="round"/></g>`;
}

function pulse(el, lt, period, delay) {
  // repeating expand-and-fade for sound arcs
  const k = ((lt - delay) % period + period) % period / period;
  if (lt < delay) { el.style.opacity = 0; return; }
  el.style.opacity = (1 - k).toFixed(2);
  el.style.transform = `scale(${(0.7 + 0.5 * k).toFixed(3)})`;
}

const ART = {
  yan: {
    svg: `
      <g class="needle">
        <circle cx="200" cy="34" r="9" fill="none" stroke="${INK.gold}" stroke-width="6"/>
        <path d="M 200 44 L 200 150" stroke="${INK.gold}" stroke-width="8" stroke-linecap="round"/>
        <path d="M 168 78 L 232 78" stroke="${INK.gold}" stroke-width="8" stroke-linecap="round"/>
        <path d="M 200 150 L 192 136 M 200 150 L 208 136" stroke="${INK.gold}" stroke-width="6" stroke-linecap="round"/>
      </g>
      <g class="box">${vessel(200, 225, INK.cyan)}
        <path d="M 160 212 L 240 212 M 160 232 L 226 232" stroke="${INK.dim}" stroke-width="5" stroke-linecap="round"/></g>
      <text class="lab1" x="265" y="92" fill="${INK.gold}" font-size="34" font-weight="800">誓いの針</text>
      <text class="lab2" x="315" y="238" fill="${INK.cyan}" font-size="34" font-weight="800">祈りを入れる器</text>
      <text class="eq" x="600" y="190" fill="${INK.gold}" font-size="90" font-weight="700">＝</text>
      <text class="kanji" x="700" y="235" fill="${INK.cream}" font-size="220" font-weight="800">言</text>`,
    update(root, lt) {
      const n = root.querySelector('.needle');
      const p = prog(lt, 0.2, 0.5);
      n.style.opacity = p.toFixed(2);
      n.style.transform = `translateY(${(-40 * (1 - easeOut(p))).toFixed(1)}px)`;
      root.querySelector('.box').style.opacity = prog(lt, 0.5, 0.4).toFixed(2);
      root.querySelector('.lab1').style.opacity = prog(lt, 0.6, 0.3).toFixed(2);
      root.querySelector('.lab2').style.opacity = prog(lt, 0.9, 0.3).toFixed(2);
      root.querySelector('.eq').style.opacity = prog(lt, 1.3, 0.3).toFixed(2);
      const k = prog(lt, 1.5, 0.35);
      const kan = root.querySelector('.kanji');
      kan.style.opacity = k.toFixed(2);
      kan.style.transform = `scale(${lerp(1.4, 1, back(k)).toFixed(3)})`;
    },
  },

  oto: {
    svg: `
      <g class="arcs" style="transform-origin: 200px 170px">${waveArcs(200, 170, 'up', 3, 40, 34, 'w')}</g>
      <g class="box">${vessel(200, 225, INK.cyan)}</g>
      <path class="line" d="M 150 222 L 250 222" stroke="${INK.red}" stroke-width="12" stroke-linecap="round"/>
      <text class="lab1" x="300" y="248" fill="${INK.red}" font-size="34" font-weight="800">器の中に一本の線</text>
      <text class="lab2" x="290" y="92" fill="${INK.gold}" font-size="34" font-weight="800">神さまの応え</text>
      <text class="eq" x="600" y="190" fill="${INK.gold}" font-size="90" font-weight="700">＝</text>
      <text class="kanji" x="700" y="235" fill="${INK.cream}" font-size="220" font-weight="800">音</text>`,
    update(root, lt) {
      root.querySelector('.box').style.opacity = prog(lt, 0.1, 0.3).toFixed(2);
      const l = prog(lt, 0.45, 0.3);
      const line = root.querySelector('.line');
      line.style.opacity = l.toFixed(2);
      line.style.filter = `drop-shadow(0 0 ${(14 * l).toFixed(1)}px ${INK.red})`;
      root.querySelector('.lab1').style.opacity = prog(lt, 0.6, 0.3).toFixed(2);
      root.querySelectorAll('.arcs .w').forEach((a, i) => {
        a.setAttribute('stroke', INK.gold);
        pulse(a, lt, 1.4, 0.9 + i * 0.25);
        a.style.transformOrigin = '200px 170px';
      });
      root.querySelector('.lab2').style.opacity = prog(lt, 1.0, 0.3).toFixed(2);
      root.querySelector('.eq').style.opacity = prog(lt, 1.4, 0.3).toFixed(2);
      const k = prog(lt, 1.6, 0.35);
      const kan = root.querySelector('.kanji');
      kan.style.opacity = k.toFixed(2);
      kan.style.transform = `scale(${lerp(1.4, 1, back(k)).toFixed(3)})`;
    },
  },

  telephone: {
    svg: `
      ${person(110, 170, INK.cream)}${person(830, 170, INK.cream)}
      <path d="M 170 150 L 770 150" stroke="${INK.dim}" stroke-width="4" stroke-dasharray="4 14" stroke-linecap="round"/>
      <path class="packet" d="M -60 0 q 10 -26 20 0 t 20 0 t 20 0 t 20 0 t 20 0 t 20 0" fill="none" stroke="${INK.gold}" stroke-width="7" stroke-linecap="round"/>
      <text x="470" y="96" text-anchor="middle" fill="${INK.gold}" font-size="40" font-weight="800">tele ＝ 遠く</text>
      <text x="470" y="262" text-anchor="middle" fill="${INK.cream}" font-size="38" font-weight="800">遠くへ声を届ける ＝ 電話</text>`,
    update(root, lt) {
      const k = ((lt * 0.8) % 1);
      const x = lerp(200, 740, ease(k));
      const pk = root.querySelector('.packet');
      pk.setAttribute('transform', `translate(${x.toFixed(1)},150)`);
      pk.style.opacity = (Math.sin(Math.PI * k)).toFixed(2);
    },
  },

  microphone: {
    svg: `
      <g class="small">${waveArcs(300, 140, 'right', 3, 10, 14, 'w')}</g>
      <rect x="425" y="60" width="90" height="140" rx="45" fill="rgba(246,239,224,0.08)" stroke="${INK.cream}" stroke-width="7"/>
      <path d="M 440 100 L 500 100 M 440 125 L 500 125 M 440 150 L 500 150" stroke="${INK.dim}" stroke-width="5" stroke-linecap="round"/>
      <path d="M 395 160 Q 395 235 470 235 Q 545 235 545 160 M 470 235 L 470 268 M 430 270 L 510 270" fill="none" stroke="${INK.cream}" stroke-width="7" stroke-linecap="round"/>
      <g class="big">${waveArcs(600, 140, 'right', 3, 40, 42, 'w')}</g>
      <text x="215" y="250" text-anchor="middle" fill="${INK.cyan}" font-size="34" font-weight="800">小さな声</text>
      <text x="740" y="250" text-anchor="middle" fill="${INK.gold}" font-size="34" font-weight="800">大きく！</text>
      <text x="470" y="40" text-anchor="middle" fill="${INK.gold}" font-size="34" font-weight="800">micro ＝ 小さい</text>`,
    update(root, lt) {
      root.querySelectorAll('.small .w').forEach((a, i) => { a.setAttribute('stroke', INK.cyan); a.style.transformOrigin = '300px 140px'; pulse(a, lt, 1.2, 0.1 + i * 0.2); });
      root.querySelectorAll('.big .w').forEach((a, i) => { a.setAttribute('stroke', INK.gold); a.style.transformOrigin = '600px 140px'; pulse(a, lt, 1.2, 0.6 + i * 0.2); });
    },
  },

  smartphone: {
    svg: `
      <rect x="385" y="10" width="170" height="280" rx="28" fill="rgba(10,14,24,0.9)" stroke="${INK.cream}" stroke-width="7"/>
      <rect x="400" y="40" width="140" height="220" rx="10" fill="rgba(159,216,236,0.1)"/>
      <path d="M 450 24 L 490 24" stroke="${INK.dim}" stroke-width="5" stroke-linecap="round"/>
      <text x="470" y="84" text-anchor="middle" fill="${INK.gold}" font-size="30" font-weight="700" font-family="Noto Serif, serif">phone</text>
      <g class="bars"></g>
      <g class="l">${waveArcs(360, 150, 'left', 3, 24, 26, 'w')}</g>
      <g class="r">${waveArcs(580, 150, 'right', 3, 24, 26, 'w')}</g>
      <text x="160" y="160" text-anchor="middle" fill="${INK.cream}" font-size="34" font-weight="800">smart</text>
      <text x="160" y="200" text-anchor="middle" fill="${INK.muted || '#b9b2a3'}" font-size="26" font-weight="700">かしこい</text>
      <text x="780" y="160" text-anchor="middle" fill="${INK.gold}" font-size="34" font-weight="800">phone</text>
      <text x="780" y="200" text-anchor="middle" fill="#b9b2a3" font-size="26" font-weight="700">声</text>`,
    init(root) {
      const g = root.querySelector('.bars');
      for (let i = 0; i < 11; i++) {
        const r = document.createElementNS('http://www.w3.org/2000/svg', 'rect');
        r.setAttribute('x', 410 + i * 11.5);
        r.setAttribute('width', 7);
        r.setAttribute('rx', 3.5);
        r.setAttribute('fill', INK.gold);
        g.appendChild(r);
      }
    },
    update(root, lt) {
      root.querySelectorAll('.bars rect').forEach((r, i) => {
        const h = 16 + 60 * Math.abs(Math.sin(lt * 5 + i * 0.9)) * (0.5 + 0.5 * Math.sin(lt * 1.7 + i));
        r.setAttribute('y', (175 - h / 2).toFixed(1));
        r.setAttribute('height', h.toFixed(1));
      });
      root.querySelectorAll('.l .w').forEach((a, i) => { a.setAttribute('stroke', INK.gold); a.style.transformOrigin = '360px 150px'; pulse(a, lt, 1.3, i * 0.25); });
      root.querySelectorAll('.r .w').forEach((a, i) => { a.setAttribute('stroke', INK.gold); a.style.transformOrigin = '580px 150px'; pulse(a, lt, 1.3, 0.12 + i * 0.25); });
    },
  },

  resonance: {
    svg: `
      <g class="f1"><path d="M 215 60 L 215 170 Q 215 200 245 200 Q 275 200 275 170 L 275 60" fill="none" stroke="${INK.cream}" stroke-width="10" stroke-linecap="round"/>
        <path d="M 245 200 L 245 260" stroke="${INK.cream}" stroke-width="10" stroke-linecap="round"/></g>
      <g class="f2"><path d="M 665 60 L 665 170 Q 665 200 695 200 Q 725 200 725 170 L 725 60" fill="none" stroke="${INK.cream}" stroke-width="10" stroke-linecap="round"/>
        <path d="M 695 200 L 695 260" stroke="${INK.cream}" stroke-width="10" stroke-linecap="round"/></g>
      <g class="w1">${waveArcs(310, 120, 'right', 3, 20, 30, 'w')}</g>
      <g class="w2">${waveArcs(630, 120, 'left', 3, 20, 30, 'w')}</g>
      <text x="245" y="296" text-anchor="middle" fill="${INK.gold}" font-size="32" font-weight="800">鳴らす</text>
      <text x="695" y="296" text-anchor="middle" fill="${INK.cyan}" font-size="32" font-weight="800">響き返す</text>
      <text x="470" y="40" text-anchor="middle" fill="${INK.gold}" font-size="34" font-weight="800">re（返す）＋ sonare（鳴る）</text>`,
    update(root, lt) {
      const v1 = 3 * Math.sin(lt * 60);
      root.querySelector('.f1').setAttribute('transform', `translate(${v1.toFixed(2)},0)`);
      const on2 = prog(lt, 0.9, 0.4);
      root.querySelector('.f2').setAttribute('transform', `translate(${(on2 * 3 * Math.sin(lt * 60 + 1)).toFixed(2)},0)`);
      root.querySelectorAll('.w1 .w').forEach((a, i) => { a.setAttribute('stroke', INK.gold); a.style.transformOrigin = '310px 120px'; pulse(a, lt, 1.1, i * 0.2); });
      root.querySelectorAll('.w2 .w').forEach((a, i) => { a.setAttribute('stroke', INK.cyan); a.style.transformOrigin = '630px 120px'; pulse(a, lt, 1.1, 0.9 + i * 0.2); });
    },
  },

  ear: {
    svg: `
      <g class="w">${waveArcs(330, 150, 'right', 4, 20, 34, 'w')}</g>
      <path d="M 560 250 Q 520 250 520 205 Q 520 170 548 150 Q 575 128 575 100 Q 575 55 620 45 Q 690 35 700 105 Q 706 150 670 180 Q 645 200 645 225 Q 645 262 605 262"
        fill="none" stroke="${INK.cream}" stroke-width="10" stroke-linecap="round"/>
      <path d="M 600 110 Q 610 80 640 88 Q 665 98 655 128 Q 648 146 630 150" fill="none" stroke="${INK.cream}" stroke-width="8" stroke-linecap="round"/>
      <text x="470" y="296" text-anchor="middle" fill="${INK.gold}" font-size="34" font-weight="800">耳を澄ませて……</text>`,
    update(root, lt) {
      root.querySelectorAll('.w .w').forEach((a, i) => { a.setAttribute('stroke', INK.gold); a.style.transformOrigin = '330px 150px'; pulse(a, lt, 1.6, i * 0.3); });
    },
  },
};
