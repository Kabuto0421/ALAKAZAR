"""Assemble actual Godot captures into review GIFs. Requires Pillow."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

OUTPUT = Path(__file__).resolve().parents[2] / "animation-review"
FONT = ImageFont.truetype("/System/Library/Fonts/Menlo.ttc", 18)
DIRECTIONS = ["UP", "RIGHT", "DOWN", "LEFT"]


def panel(label, direction, tick, caption=None):
    canvas = Image.new("RGB", (384, 416), "#111820")
    frames = sorted((OUTPUT / label / str(direction)).glob("*.png"))
    canvas.paste(Image.open(frames[min(tick, len(frames)-1)]), (0, 32))
    label_text = caption if caption else f"{label.upper()} / {DIRECTIONS[direction]}"
    ImageDraw.Draw(canvas).text((12, 6), label_text, font=FONT, fill="white")
    return canvas


def save_gif(frames, filename):
    # Capture is 60 fps; sample every second frame for portable 30 fps GIF timing.
    durations = [30, 30, 40] * (len(frames) // 3 + 1)
    durations = durations[:len(frames)]
    durations[-1] += 400
    frames[0].save(OUTPUT / filename, save_all=True, append_images=frames[1:],
                   duration=durations, loop=0, disposal=2)


def main():
    final, comparison, timing_comparison = [], [], []
    frame_count = len(list((OUTPUT / "after/0").glob("*.png")))
    for tick in range(0, frame_count, 2):
        four = Image.new("RGB", (768, 832))
        for direction in range(4):
            four.paste(panel("after", direction, tick), ((direction % 2)*384, (direction // 2)*416))
        final.append(four)
        pair = Image.new("RGB", (768, 416))
        pair.paste(panel("before", 1, tick), (0, 0))
        pair.paste(panel("after", 1, tick), (384, 0))
        comparison.append(pair)
        if (OUTPUT / "timing-before").exists():
            timing_pair = Image.new("RGB", (768, 416))
            timing_pair.paste(panel("timing-before", 1, tick, "0.40 / 0.20 s"), (0, 0))
            timing_pair.paste(panel("after", 1, tick, "0.25 / 0.20 s"), (384, 0))
            timing_comparison.append(timing_pair)
    save_gif(final, "sword-four-directions.gif")
    save_gif(comparison, "sword-right-comparison.gif")
    if timing_comparison:
        save_gif(timing_comparison, "sword-right-timing-comparison.gif")
    contact = Image.new("RGB", (384*5, 416*4))
    samples = json.loads((OUTPUT / "after/samples.json").read_text())
    for direction in range(4):
        hit_tick = next(sample['tick'] for sample in samples
                        if sample['direction'] == direction and sample['enemy_hp'] == 1)
        follow_tick = next(sample['tick'] for sample in samples
                           if sample['direction'] == direction and sample['tick'] > hit_tick
                           and sample['frame'] > (3 if direction == 0 else 2))
        for column, tick in enumerate([0, hit_tick-4, hit_tick, follow_tick, frame_count-1]):
            contact.paste(panel("after", direction, tick), (column*384, direction*416))
    contact.save(OUTPUT / "game-contact-sheet.png")
    print(OUTPUT / "sword-four-directions.gif")


if __name__ == "__main__":
    main()
