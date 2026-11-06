# Night Freight

A 2D action side-scroller built in **Godot 4** (GDScript), set aboard a Japanese
ghost train running through the night. Cross seven carriages of dark wood and
warm lantern light, from the locomotive to the shrine car, and reach the end of
the train.

## Gameplay

- Run, jump and **double jump**, dash, and attack (left mouse click)
- Benches are checkpoints: death returns you to the last bench you rested at
- Resting at a bench restores you, and resets the train's enemies
- Enemies patrol the carriages; levers open the way between cars

## Status

A finished test project, designed and directed by **Zin Min Htut** and built
with Muse between 30 October and 1 November 2026. It was completed as a
private test and is published here as the complete project source.

## What is in this repository

Everything the project is made of:

- All GDScript source (`.gd`) and UID files
- All scenes (`.tscn`): main, menu, player, enemies, props
- `project.godot`, `export_presets.cfg`, and the full set of `.import` records
- **All binary assets**: sprites, carriage backgrounds, UI art, music and sound
  effects (about 46 MB of PNG and WAV files)

Clone it, open the folder in Godot 4, and the project runs. The first open
imports the assets, which can take a moment.

## Layout

- `main.tscn` / `main.gd`: the scrolling level, seven carriages end to end
- `menu.tscn` / `menu.gd`: title screen and settings
- `player.tscn`: the heroine, her movement, combat and animation states
- `bench.gd`, `lever.gd`, `save_system.gd`, `audio_settings.gd`: game systems
- `assets/`: all art and audio assets with their `.import` records
- `test.tscn`: the automated test scene used to verify every build
