# Mockups

Cyber-style battle screen mockups (not the in-game implementation).

| File | Content |
| --- | --- |
| `battle_threat_off.png` | Normal view |
| `battle_threat_on.png` | Threat display on: red numbers show how many antivirus pieces can hit each tile |
| `battle_mockup.html` | Source. Uses the repository's fonts and sprites; in the script, set `threat = {}` to get the "off" view |

To re-render at game resolution (1728×1080), open the HTML in Chromium with a 1152×720 viewport and device scale factor 1.5 (local file access must be allowed so the fonts and sprites load).
