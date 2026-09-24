# Encounter layouts

Open `encounter_01.tscn`, `encounter_02.tscn`, or `encounter_03.tscn` in Godot's 2D editor to arrange enemies.

- Drag an enemy marker to another tile. Markers snap to the 6×6 grid.
- Add a `Node2D` child with `enemy_placement.gd` to add an enemy.
- Set `enemy_kind` in the Inspector: Infantry, Miner, Heavy, or Cavalry (跳躍騎兵).
- Duplicate a marker to add another enemy; remove one to reduce the encounter.

Each marker's position is the enemy's board cell. Keep one enemy per tile and leave the bottom row open for the player.
