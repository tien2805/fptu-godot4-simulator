# Source of these files

The files under `docs/engine-reference/` (README.md and `godot/`) are copied from
[Claude Code Game Studios](https://github.com/Donchitos/Claude-Code-Game-Studios) by Donchitos,
commit `05ad7c8a5b8aa2aa86bbd3439ae7cf7295cac418`, on 2026-11-09. They are MIT licensed; the
license text is in `LICENSE-claude-code-game-studios.txt` next to this file.

## Local changes
- `godot/VERSION.md`: "Installed at pin time" is filled in with this project's editor
  (4.7.2.stable.official.ed1daf0bf).

## How this project uses them
- Before writing or reviewing Godot API code, check `godot/deprecated-apis.md` and the
  4.5-4.7 sections of `godot/breaking-changes.md`. The project runs Godot 4.7.2, pure GDScript,
  no C# and no GDExtension.
- The Unity and Unreal folders of the source repo are not copied. Neither is the rest of the
  framework (its agents, skills, hooks and settings).
