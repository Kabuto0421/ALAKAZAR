"""Narration synthesis for an episode.

Engines (``--engine``):
    su-shiki   WEB版VOICEVOX API (api.su-shiki.com). Needs VOICEVOX_API_KEY.
    local      A VOICEVOX engine running on this machine (default port 50021).
    openjtalk  Offline placeholder voice via pyopenjtalk. Only for checking
               timing; the finished video should use VOICEVOX.
    auto       su-shiki if VOICEVOX_API_KEY is set, else local if the engine
               answers, else openjtalk.

Each line is cached under cache/tts/ by (engine, speaker, speed, text), so
re-running after a script tweak only re-synthesizes the lines that changed.
"""

import hashlib
import io
import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request
import wave

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE_DIR = os.path.join(HERE, "cache", "tts")
SU_SHIKI_URL = "https://api.su-shiki.com/v2/voicevox/audio/"
LOCAL_URL = os.environ.get("VOICEVOX_ENGINE_URL", "http://127.0.0.1:50021")


def _http(url, data=None, headers=None, timeout=60):
    req = urllib.request.Request(url, data=data, headers=headers or {})
    with urllib.request.urlopen(req, timeout=timeout) as res:
        return res.read(), res.headers.get("Content-Type", "")


def _su_shiki(text, voice):
    key = os.environ.get("VOICEVOX_API_KEY")
    if not key:
        raise RuntimeError("VOICEVOX_API_KEY が設定されていません")
    query = urllib.parse.urlencode({
        "key": key,
        "speaker": voice["speaker"],
        "pitch": voice.get("pitch", 0),
        "intonationScale": voice.get("intonation", 1),
        "speed": voice.get("speed", 1),
        "text": text,
    })
    for attempt in range(5):
        try:
            body, ctype = _http(f"{SU_SHIKI_URL}?{query}", timeout=120)
        except urllib.error.HTTPError as err:
            body, ctype = err.read(), err.headers.get("Content-Type", "")
        if body[:4] == b"RIFF":
            return body
        # Errors come back as JSON, e.g. {"errorMessage": "notEnoughPoints"}.
        message = body[:200].decode("utf-8", "replace")
        if "invalidApiKey" in message or "notEnoughPoints" in message:
            raise RuntimeError(f"VOICEVOX API: {message}")
        time.sleep(2 ** attempt)
    raise RuntimeError(f"VOICEVOX API が音声を返しませんでした: {message}")


def _local(text, voice):
    q = urllib.parse.urlencode({"text": text, "speaker": voice["speaker"]})
    body, _ = _http(f"{LOCAL_URL}/audio_query?{q}", data=b"")
    query = json.loads(body)
    query["speedScale"] = voice.get("speed", 1)
    query["pitchScale"] = voice.get("pitch", 0)
    query["intonationScale"] = voice.get("intonation", 1)
    body, _ = _http(
        f"{LOCAL_URL}/synthesis?speaker={voice['speaker']}",
        data=json.dumps(query).encode(),
        headers={"Content-Type": "application/json"},
        timeout=120,
    )
    return body


def _openjtalk(text, voice):
    import numpy as np
    import pyopenjtalk

    samples, rate = pyopenjtalk.tts(text, speed=voice.get("speed", 1))
    pcm = np.clip(samples, -32768, 32767).astype("<i2")
    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(pcm.tobytes())
    return buf.getvalue()


ENGINES = {"su-shiki": _su_shiki, "local": _local, "openjtalk": _openjtalk}


def resolve_engine(name):
    if name != "auto":
        return name
    if os.environ.get("VOICEVOX_API_KEY"):
        return "su-shiki"
    try:
        _http(f"{LOCAL_URL}/version", timeout=2)
        return "local"
    except (OSError, urllib.error.URLError):
        return "openjtalk"


def wav_duration(path):
    with wave.open(path, "rb") as w:
        return w.getnframes() / w.getframerate()


def synthesize(text, voice, engine):
    """Return the path of a cached WAV for ``text``."""
    spec = {"engine": engine, "text": text, **{k: voice.get(k) for k in ("speaker", "speed", "pitch", "intonation")}}
    digest = hashlib.sha1(json.dumps(spec, sort_keys=True, ensure_ascii=False).encode()).hexdigest()[:16]
    path = os.path.join(CACHE_DIR, engine, f"{digest}.wav")
    if not os.path.exists(path):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        data = ENGINES[engine](text, voice)
        with open(path + ".tmp", "wb") as f:
            f.write(data)
        os.replace(path + ".tmp", path)
    return path
