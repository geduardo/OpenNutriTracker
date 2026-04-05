---
name: Build workflow lessons learned
description: Critical lessons about hive_generator removal, build_runner, and adapter file management
type: feedback
---

Never delete .dart_tool/build or run build_runner clean — it wipes Hive adapter .g.dart files that hive_generator used to produce but no longer does (removed due to Flutter 3.41 incompatibility).

**Why:** hive_generator 2.0.1 is incompatible with Flutter 3.41+ due to analyzer version conflicts. We removed it from pubspec.yaml but the Hive TypeAdapters still need to exist.

**How to apply:**
- All Hive TypeAdapters now live in `_adapter.dart` files (e.g. `config_dbo_adapter.dart`) as `part of` the source DBO file
- `.g.dart` files are ONLY for `json_serializable` output — build_runner manages these
- DBOs with both @HiveType and @JsonSerializable have TWO part files: `_adapter.dart` (hand-written) + `.g.dart` (auto-generated)
- Hive-only DBOs (no @JsonSerializable) only have `_adapter.dart`, no `.g.dart`
- NEVER run `rm -rf .dart_tool/build` — it forces full regeneration which is safe for .g.dart but can cause confusion
- The user was unhappy about removing hive_generator — acknowledge the trade-off, don't dismiss concerns about removing packages
