#!/usr/bin/env python3
"""Build a 語源の旅 short: narration -> timeline -> audio mix -> frames -> MP4.

    python3 build.py sin                     # VOICEVOX if available, else placeholder voice
    python3 build.py sin --engine su-shiki   # WEB版VOICEVOX API (needs VOICEVOX_API_KEY)
    python3 build.py sin --engine local      # VOICEVOX engine on 127.0.0.1:50021
    python3 build.py sin --stills 3,20,60    # only render a few PNG frames for checking

Output goes to build/<episode>/ : <episode>.mp4, timeline.json, audio.wav,
description.txt (post text with credits and sources).
"""

import argparse
import json
import os
import subprocess
import sys

import audio
import tts

HERE = os.path.dirname(os.path.abspath(__file__))

LEAD_IN = 0.2  # the hook starts almost immediately
LINE_GAP = 0.12  # pause between lines in the same scene
SCENE_GAP = 0.45  # extra pause before a new scene, while the globe travels
TAIL = 3.4  # end card after the last line
SCENE_LEAD = 0.45  # the camera starts moving this long before a scene's first line
ERA_ROLL = 1.1  # seconds the era counter rolls when a scene sets a new era


MET_API = "https://collectionapi.metmuseum.org/public/collection/v1/objects/"


def fetch_images(episode):
    """Download the episode's museum images (Met Open Access, public domain) into cache/images/."""
    import urllib.request

    out = {}
    folder = os.path.join(HERE, "cache", "images")
    os.makedirs(folder, exist_ok=True)
    for key, spec in episode.get("images", {}).items():
        meta_path = os.path.join(folder, f"met-{spec['met']}.json")
        if not os.path.exists(meta_path):
            with urllib.request.urlopen(MET_API + str(spec["met"]), timeout=60) as res:
                meta = json.load(res)
            if not meta.get("isPublicDomain"):
                raise RuntimeError(f"Met object {spec['met']} is not public domain")
            with open(meta_path, "w", encoding="utf-8") as f:
                json.dump(meta, f, ensure_ascii=False)
        with open(meta_path, encoding="utf-8") as f:
            meta = json.load(f)
        img_path = os.path.join(folder, f"met-{spec['met']}.jpg")
        if not os.path.exists(img_path):
            with urllib.request.urlopen(meta["primaryImageSmall"], timeout=120) as res:
                data = res.read()
            with open(img_path, "wb") as f:
                f.write(data)
        out[key] = {
            "src": f"/cache/images/met-{spec['met']}.jpg",
            "title": meta.get("title", ""),
            "artist": meta.get("artistDisplayName", ""),
            "date": meta.get("objectDate", ""),
            "url": meta.get("objectURL", ""),
        }
    return out


def build_timeline(episode, engine):
    """Synthesize every line and turn relative cues into absolute seconds.

    In the episode file, cue times ("at", "len") are fractions of the line's
    spoken duration, so they stay in sync whichever voice engine is used.
    """
    voice = episode["voice"]
    cursor = LEAD_IN
    lines, scenes, clips = [], [], []
    ev = {"fx": [], "routes": [], "eras": [], "cardSets": [], "cardStates": [], "marks": [], "camera": []}
    for si, scene in enumerate(episode["scenes"]):
        if si > 0:
            cursor += SCENE_GAP
        scene_start = max(0.0, cursor - SCENE_LEAD) if si > 0 else 0.0
        ev["camera"].append({"t": scene_start, **scene["camera"]})
        if "era" in scene:
            era = scene["era"] if isinstance(scene["era"], dict) else {"value": scene["era"]}
            ev["eras"].append({"t": scene_start + 0.3, "value": era["value"], "label": era.get("label"), "dur": ERA_ROLL})
        for li, line in enumerate(scene["lines"]):
            path = tts.synthesize(line.get("say", line["text"]), {**voice, **line.get("voice", {})}, engine)
            dur = tts.wav_duration(path)
            start = cursor

            def at(frac):
                return round(start + frac * dur, 3)

            index = len(lines)
            lines.append({"text": line["text"], "scene": scene["id"], "start": round(start, 3), "end": round(start + dur, 3)})
            clips.append((start, path))
            if "cards" in line:
                ev["cardSets"].append({"t": 0.0 if index == 0 else round(start, 3), "cards": line["cards"], "line": index})
            if "cardState" in line:
                ev["cardStates"].append({"t": round(start, 3), "state": line["cardState"]})
            if "camera" in line:
                ev["camera"].append({"t": round(start, 3), **line["camera"]})
            for place in line.get("mark", []):
                ev["marks"].append({"t": round(start, 3), "place": place, "scene": scene["id"]})
            if "era" in line:
                era = line["era"] if isinstance(line["era"], dict) else {"value": line["era"]}
                ev["eras"].append({"t": round(start, 3), "value": era["value"], "label": era.get("label"), "dur": round(era.get("len", 0) * dur, 3) or ERA_ROLL})
            for r in line.get("routes", []):
                ev["routes"].append({**r, "t": at(r.get("at", 0)), "dur": round(r.get("len", 0.8) * dur, 3), "scene": scene["id"]})
            for fx in line.get("fx", []):
                cue = {k: v for k, v in fx.items() if k not in ("at", "len")}
                cue.update({"t": at(fx.get("at", 0)), "dur": round(fx.get("len", 0.25) * dur, 3), "line": index})
                ev["fx"].append(cue)
                if "state" in fx:
                    ev["cardStates"].append({"t": cue["t"], "state": fx["state"]})
            print(f"  [{scene['id']:>8}] {start:6.2f}s +{dur:4.2f}s  {line['text']}")
            cursor += dur + LINE_GAP
        scenes.append({k: v for k, v in scene.items() if k not in ("lines", "camera")} | {"start": round(scene_start, 3)})
    last_end = cursor - LINE_GAP
    ev["cardSets"].append({"t": round(last_end + 0.5, 3), "cards": ["end"], "line": None})
    duration = last_end + TAIL
    for i, scene in enumerate(scenes):
        scene["end"] = scenes[i + 1]["start"] if i + 1 < len(scenes) else round(duration, 3)
    for key in ev:
        ev[key].sort(key=lambda e: e["t"])
    timeline = {k: v for k, v in episode.items() if k != "scenes"}
    timeline.update({"engine": engine, "duration": round(duration, 3), "scenes": scenes, "lines": lines, "events": ev, "images": fetch_images(episode)})
    return timeline, clips


def description(episode, engine):
    voice = episode["voice"]["name"] if engine in ("su-shiki", "local") else "Open JTalk（仮音声）"
    credit = f"VOICEVOX:{voice}" if engine in ("su-shiki", "local") else voice
    titles = episode.get("titles") or [f"{episode['word']}（{episode['wordJa']}）"]
    parts = [
        f"{titles[0]}【{episode['series']} #{episode['number']}】",
        "",
        episode.get("hook", ""),
        episode.get("cta", ""),
        "",
        "音声: " + credit,
        "",
        "参考:",
        *[f"・{s}" for s in episode.get("sources", [])],
        *(["", "画像: メトロポリタン美術館 Open Access（パブリックドメイン）"] if episode.get("images") else []),
        *[f"・{m['title']}" + (f"（{m['artist']}, {m['date']}）" if m.get("artist") else f"（{m['date']}）") for m in fetch_images(episode).values()],
        "",
        " ".join(f"#{t}" for t in episode.get("tags", ["語源", episode["word"], episode["wordJa"], "言語学", "雑学", "Shorts"])),
    ]
    return "\n".join(parts) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("episode", help="episodes/<name>.json")
    parser.add_argument("--engine", default="auto", choices=["auto", *tts.ENGINES])
    parser.add_argument("--fps", type=int, default=30)
    parser.add_argument("--workers", type=int, default=max(1, min(4, (os.cpu_count() or 2))))
    parser.add_argument("--stills", help="comma-separated seconds; render PNGs only")
    parser.add_argument("--remux", action="store_true", help="re-mix audio onto the frames already rendered")
    parser.add_argument("--thumbs", action="store_true", help="render the thumbnail variants only")
    args = parser.parse_args()

    with open(os.path.join(HERE, "episodes", f"{args.episode}.json"), encoding="utf-8") as f:
        episode = json.load(f)

    engine = tts.resolve_engine(args.engine)
    print(f"voice engine: {engine}")
    if engine == "openjtalk":
        print("  ※ 仮音声です。VOICEVOX_API_KEY を設定するか VOICEVOX を起動すると本番音声になります。")

    out_dir = os.path.join(HERE, "build", episode["id"])
    os.makedirs(out_dir, exist_ok=True)
    timeline, clips = build_timeline(episode, engine)
    timeline["fps"] = args.fps
    timeline_path = os.path.join(out_dir, "timeline.json")
    with open(timeline_path, "w", encoding="utf-8") as f:
        json.dump(timeline, f, ensure_ascii=False, indent=1)
    print(f"duration: {timeline['duration']:.1f}s")

    render = ["node", os.path.join(HERE, "render.mjs"), timeline_path]
    if args.thumbs:
        subprocess.run(render + ["--thumbs", os.path.join(HERE, "episodes", f"{args.episode}.json")], check=True)
        with open(os.path.join(out_dir, "description.txt"), "w", encoding="utf-8") as f:
            f.write(description(episode, engine))
        return
    if args.stills:
        subprocess.run(render + ["--stills", args.stills], check=True)
        return

    audio_path = os.path.join(out_dir, "audio.wav")
    audio.write_wav(audio_path, audio.mix(timeline["duration"], clips, timeline["scenes"], timeline["events"]["fx"]))
    with open(os.path.join(out_dir, "description.txt"), "w", encoding="utf-8") as f:
        f.write(description(episode, engine))

    video_path = os.path.join(out_dir, f"{episode['id']}.mp4")
    extra = ["--mux-only"] if args.remux else []
    subprocess.run(render + ["--audio", audio_path, "--out", video_path, "--workers", str(args.workers), *extra], check=True)
    print(f"done: {video_path}")


if __name__ == "__main__":
    sys.exit(main())
