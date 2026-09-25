// Capture render/index.html frame by frame with headless Chromium and encode an MP4.
//
//   node render.mjs build/sin/timeline.json --audio build/sin/audio.wav --out build/sin/sin.mp4
//   node render.mjs build/sin/timeline.json --stills 0,3.5,20
//   node render.mjs build/sin/timeline.json --thumbs episodes/sin.json
//
// Frames are split across several pages (--workers) that each encode a segment;
// the segments are then joined and muxed with the audio without re-encoding.
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { spawn, execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';

const ROOT = path.dirname(fileURLToPath(import.meta.url));
const W = 1080, H = 1920;

function parseArgs(argv) {
  const opts = { workers: 4 };
  const rest = [];
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith('--')) opts[a.slice(2)] = argv[i + 1] && !argv[i + 1].startsWith('--') ? argv[++i] : true;
    else rest.push(a);
  }
  opts.timeline = rest[0];
  opts.workers = Number(opts.workers) || 1;
  return opts;
}

function ffmpegPath() {
  if (process.env.FFMPEG) return process.env.FFMPEG;
  try {
    return execFileSync('python3', ['-c', 'import imageio_ffmpeg; print(imageio_ffmpeg.get_ffmpeg_exe())']).toString().trim();
  } catch {
    return 'ffmpeg';
  }
}

const TYPES = { '.jpg': 'image/jpeg', '.png': 'image/png', '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json', '.woff2': 'font/woff2', '.woff': 'font/woff' };
function serve() {
  const server = http.createServer((req, res) => {
    const url = decodeURIComponent(new URL(req.url, 'http://x').pathname);
    const file = path.join(ROOT, url);
    if (!file.startsWith(ROOT) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
      res.writeHead(404).end();
      return;
    }
    res.writeHead(200, { 'Content-Type': TYPES[path.extname(file)] || 'application/octet-stream' });
    fs.createReadStream(file).pipe(res);
  });
  return new Promise((resolve) => server.listen(0, '127.0.0.1', () => resolve(server)));
}

async function openPage(browser, base, timelineRel) {
  const page = await browser.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: 1 });
  page.on('pageerror', (e) => console.error('page error:', e.message));
  await page.goto(`${base}/render/index.html?timeline=/${timelineRel}`);
  const info = await page.evaluate(() => window.ready);
  const cdp = await page.context().newCDPSession(page);
  const grab = async (t) => {
    await page.evaluate(async (tt) => {
      window.renderFrame(tt);
      await document.fonts.ready;
    }, t);
    const { data } = await cdp.send('Page.captureScreenshot', { format: 'png', optimizeForSpeed: true });
    return Buffer.from(data, 'base64');
  };
  return { page, info, grab };
}

function encoder(ffmpeg, fps, out) {
  const proc = spawn(ffmpeg, [
    '-v', 'error', '-y', '-f', 'image2pipe', '-framerate', String(fps), '-c:v', 'png', '-i', '-',
    '-c:v', 'libx264', '-preset', 'medium', '-crf', '17', '-pix_fmt', 'yuv420p', '-r', String(fps), out,
  ], { stdio: ['pipe', 'inherit', 'inherit'] });
  const done = new Promise((resolve, reject) => proc.on('close', (code) => (code === 0 ? resolve() : reject(new Error(`ffmpeg exited ${code}`)))));
  const write = (buf) => new Promise((resolve) => (proc.stdin.write(buf) ? resolve() : proc.stdin.once('drain', resolve)));
  return { write, end: () => { proc.stdin.end(); return done; } };
}

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  const timelineAbs = path.resolve(opts.timeline);
  const timelineRel = path.relative(ROOT, timelineAbs).split(path.sep).join('/');
  const outDir = path.dirname(timelineAbs);
  const server = await serve();
  const base = `http://127.0.0.1:${server.address().port}`;
  const browser = await chromium.launch({ args: ['--force-color-profile=srgb', '--font-render-hinting=none', '--disable-lcd-text'] });
  try {
    if (opts.thumbs) {
      // thumbnails come straight from the episode file: --thumbs episodes/sin.json
      const epRel = path.relative(ROOT, path.resolve(opts.thumbs)).split(path.sep).join('/');
      const ep = JSON.parse(fs.readFileSync(path.resolve(opts.thumbs), 'utf8'));
      for (const t of ep.thumbnails || []) {
        const page = await browser.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: 1 });
        page.on('pageerror', (e) => console.error('page error:', e.message));
        await page.goto(`${base}/render/thumb.html?episode=/${epRel}&id=${t.id}`);
        await page.evaluate(() => window.ready);
        const file = path.join(outDir, `thumb_${t.id}.png`);
        await page.screenshot({ path: file });
        await page.close();
        console.log(file);
      }
      return;
    }
    if (opts.stills) {
      const { grab } = await openPage(browser, base, timelineRel);
      const dir = path.join(outDir, 'stills');
      fs.mkdirSync(dir, { recursive: true });
      for (const s of String(opts.stills).split(',')) {
        const t = Number(s);
        const file = path.join(dir, `t${t.toFixed(2).padStart(6, '0')}.png`);
        fs.writeFileSync(file, await grab(t));
        console.log(file);
      }
      return;
    }

    const ffmpeg = ffmpegPath();
    const segDir = path.join(outDir, 'segments');
    const list = path.join(segDir, 'list.txt');
    if (!opts['mux-only'] || !fs.existsSync(list)) {
      await renderSegments(browser, base, timelineRel, ffmpeg, segDir, list, opts.workers);
    }
    const out = path.resolve(opts.out || path.join(outDir, 'video.mp4'));
    const args = ['-v', 'error', '-y', '-f', 'concat', '-safe', '0', '-i', list];
    if (opts.audio) args.push('-i', path.resolve(opts.audio), '-c:a', 'aac', '-b:a', '192k', '-shortest');
    args.push('-c:v', 'copy', '-movflags', '+faststart', out);
    execFileSync(ffmpeg, args, { stdio: 'inherit' });
    console.log(`wrote ${out}`);
  } finally {
    await browser.close();
    server.close();
  }
}

async function renderSegments(browser, base, timelineRel, ffmpeg, segDir, list, workerCount) {
  {
    const first = await openPage(browser, base, timelineRel);
    const { duration, fps } = first.info;
    const total = Math.ceil(duration * fps);
    const workers = Math.max(1, Math.min(workerCount, 8));
    const chunk = Math.ceil(total / workers);
    fs.mkdirSync(segDir, { recursive: true });
    const pages = [first];
    for (let i = 1; i < workers; i++) pages.push(await openPage(browser, base, timelineRel));
    let doneFrames = 0;
    const started = Date.now();
    const segs = await Promise.all(pages.map(async (p, w) => {
      const a = w * chunk, b = Math.min(total, a + chunk);
      const seg = path.join(segDir, `seg${w}.mp4`);
      if (a >= b) return null;
      const enc = encoder(ffmpeg, fps, seg);
      for (let f = a; f < b; f++) {
        await enc.write(await p.grab(f / fps));
        doneFrames++;
        if (w === 0 && f % 30 === 0) {
          const rate = doneFrames / ((Date.now() - started) / 1000);
          process.stdout.write(`\r  frames ${doneFrames}/${total}  ${rate.toFixed(1)} fps  `);
        }
      }
      await enc.end();
      return seg;
    }));
    process.stdout.write('\n');
    fs.writeFileSync(list, segs.filter(Boolean).map((s) => `file '${s}'`).join('\n'));
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
