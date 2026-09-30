extends RefCounted
## Two-line breaks for short Japanese summaries. Autowrap breaks between any two
## characters, which can leave one kana alone on the second line (弾／く); this
## breaks after a separator or particle as close to the middle as fits instead.

const BREAK_AFTER := "・、。をにでがはのと"

## `text` with a newline where it should wrap to fit `width` (unchanged if it fits).
static func split(text: String, font: Font, font_size: int, width: float) -> String:
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= width:
		return text
	var best := -1
	var middle := text.length() / 2.0
	for i in range(1, text.length() - 1):
		var head := text.substr(0, i + 1)
		if font.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
			break
		# A break after a separator or particle, leaving at least two characters below.
		if BREAK_AFTER.contains(text[i]) and text.length() - i - 1 >= 2:
			if best < 0 or absf(i + 1 - middle) < absf(best - middle):
				best = i + 1
	if best < 0:
		# No natural break: split evenly.
		best = int(ceil(middle))
	return text.substr(0, best) + "\n" + text.substr(best)
