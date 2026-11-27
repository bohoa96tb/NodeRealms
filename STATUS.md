# NODE REALMS - Project Status

**Engine:** Godot 4.3 (`gl_compatibility`, GDScript only, zero external assets/CDNs)  
**Target Platform:** Android (`720x1280` portrait, `canvas_items` / `expand`, `import_etc2_astc=true`, one-handed touch)  
**Main Scene:** `res://scenes/MainHubScene.tscn`  
**Autoloads:** `SaveManager` (`res://scripts/save_manager.gd`), `AudioManager` (`res://scripts/audio_manager.gd`)  
**Current Milestone:** P3 Part 1 Complete + Android APK/AAB GitHub Actions CI (`18c24fa`)

---

## 1. Completed Features

### P0 - Core RTS Prototype
- Symmetrical graph battle mechanics with `BaseNode` (`NEUTRAL`, `PLAYER`, `ENEMY`) and group-based `ArmyGroup` (`220 px/s`) to optimize mobile performance.
- One-handed mouse & native touch drag-and-drop dispatch (`25%`, `50%`, `75%`, `100%` deploy ratio buttons).
- Combat resolution (`attack_power` vs `defense_power`), reinforcement capped at `max_troops`, and `VICTORY` / `DEFEAT` flow.

### P1 - Procedural Map Generation & Portals
- `GeometryBlueprints`: 16 normalized anonymous blueprints (`[0.0, 1.0]`) across Tier 1–4.
- `MapGenerator`: seed-based transforms, segment intersection splitting, vertex clustering (`100 px` merge threshold), 2-way `portal_pairs` connecting separated clusters, and max-graph-distance `PLAYER` / `ENEMY` placement.
- `MapValidator`: enforces `4..25` nodes, `>= 110 px` minimum node spacing, full connectivity (edges + portals), and `>= 2` hops between starting factions (up to 20 seed retries + safe fallback).
- Portal visuals & gameplay: rotating orchid/cyan node halos, pulsing dashed `Line2D` portal links, `1.8x` travel speed with warp trail; both Player and AI can use Portals.

### P2 Part 1 - 4 MVP Creatures & Active Skills
- 4 elemental creatures in `CreatureData` & `CreatureManager`:
  - **Flame Golem** (`FIRE`): *Blaze Surge* (`+40%`+ Attack for `6s`).
  - **Aqua Spirit** (`WATER`): *Tidal Mend* (instant `+6`+ troops heal to all `PLAYER` bases).
  - **Forest Guardian** (`NATURE`): *Verdant Bloom* (`2.0x`+ production speed for `8s`).
  - **Stone Titan** (`EARTH`): *Iron Bastion* (`+50%`+ defense for `7s`).
- Visual feedback: skill shockwave ripples, pulsing buff rings on `PLAYER` nodes, fiery aura on `FIRE`-buffed `ArmyGroup`s, and HUD `SkillBtn` (Ready / `ACTIVE (Xs)` / Cooldown) + quick swap button.

### P2 Part 2 - 15-Level Campaign, Offline JSON Save/Load & Rewards
- `SaveManager`: saves/loads `user://node_realms_save.json` (`version: 1`) with automatic default creation, corrupted JSON recovery, and backward-compatible field migration.
- `CampaignData`: 15 stages in **VERDANT REALM** across Tier 1–4 with `EASY` (`3.0s`), `NORMAL` (`2.2s`), and `HARD` (`1.6s`) AI profiles in `AIController`.
- Post-battle bonus tracking: **Capture All Nodes** (`+30 Gold`), **No Base Lost** (`+20 Gold`), **Fast Clear `<90s`** (`+20 Gold`), itemized Victory/Defeat popups, and auto-unlocking progression.

### P2 Part 3 - Main Hub (3 Tabs) & Kingdom Island
- `MainHubScene`: unified portrait hub with persistent Top Bar (`NODE REALMS`, Kingdom Level, `GOLD`, `ESSENCE`, `SFX: ON/OFF`) and Bottom Tab Bar (`Campaign` | `Creatures` | `Kingdom`).
- **Campaign Tab**: `3x5` Verdant Realm level grid (completed checkmark badges, unlocked highlight, `[Locked]` state), `Sandbox Mode`, and `Test Boss`.
- **Creatures Tab**: 4 creature cards with `_draw()` elemental emblems, level `1–5` upgrades via Essence (`30/60/100/150`), and persistent `Equip`.
- **Kingdom Tab**: procedural floating island (`KingdomIsland` `_draw()`), 5 buildings (`Castle`, `Gold Mine` passive `+10 Gold/min` x level with 4h cap & `Claim`, `Barracks` `+3 max_troops`/level, `Laboratory` `-5%` cooldown/level, `Creature Habitat` `+5%` Essence/level) capped by Castle level (`100/200/350/550 Gold`).

### P3 Part 1 - Boss Battle (Level 15), Combat VFX, Procedural SFX & Android CI
- **Verdant Overlord (Level 15 Boss)**: `is_boss_node` (`56 px` radius, `80` max troops, `0.85/s` production, `1.15x` power multiplier, `35` starting troops, rotating crimson-purple crown, `BOSS` tag). Every `12s`, telegraphs `2s` (`BOSS SKILL: OVERGROWTH SURGE!`), summons `+8` troops, and launches a `40%` surge.
- **Combat VFX**: `CPUParticles2D` capture bursts, expanding faction shockwaves, hostile impact white flash + troop label scale pop, and `Camera2D` screen shake.
- **Procedural SFX (`AudioManager`)**: 9 in-memory 16-bit `AudioStreamWAV` sounds (`select`, `send`, `capture`, `lost`, `portal`, `skill`, `victory`, `defeat`, `boss_skill`), 8-player pool with anti-spam throttling, and persisted `SFX: ON/OFF` toggle.
- **Android Build CI**: `export_presets.cfg` (`com.bohoa.noderealms`, `arm64-v8a` + `armeabi-v7a`) and `.github/workflows/build-android.yml` (Ubuntu + JDK 17 + Android SDK 34 + Godot `4.3-stable` headless -> `NodeRealms-debug.apk`, plus conditional `NodeRealms-release.aab` when Release Keystore Secrets are configured).

---

## 2. Core File Inventory

| File | Role |
| --- | --- |
| `project.godot` | Project settings, Main Scene (`MainHubScene.tscn`), Autoloads (`SaveManager`, `AudioManager`), portrait & GL Compatibility config |
| `export_presets.cfg` | Godot 4.3 Android export preset (`com.bohoa.noderealms`, `arm64-v8a`, `armeabi-v7a`) |
| `.github/workflows/build-android.yml` | GitHub Actions pipeline building Debug APK and conditional Release AAB |
| `scenes/MainHubScene.tscn`, `scripts/main_hub.gd`, `scripts/kingdom_island.gd` | 3-tab Main Hub UI and procedural Kingdom floating island renderer |
| `scenes/BattleScene.tscn`, `scripts/battle_manager.gd` | Dynamic map loading, 1-handed drag/drop, Boss skill loop, VFX, HUD & reward popups |
| `scenes/BaseNode.tscn`, `scripts/base_node.gd` | Base node simulation, Boss state, buffs, shockwave & impact VFX |
| `scenes/ArmyGroup.tscn`, `scripts/army_group.gd` | Group-based marching units, Portal warp speed, combat resolution |
| `scripts/ai_controller.gd` | 3-difficulty AI (`EASY`, `NORMAL`, `HARD`) with Portal awareness |
| `scripts/geometry_blueprints.gd`, `scripts/map_generator.gd`, `scripts/map_validator.gd` | Procedural map pipeline, Portal cluster linking, and map validation |
| `scripts/creature_data.gd`, `scripts/creature_manager.gd` | 4 MVP creature definitions, level scaling, active skill & cooldown state |
| `scripts/campaign_data.gd`, `scripts/kingdom_data.gd` | 15-level Verdant Realm data and 5 Kingdom building definitions |
| `scripts/save_manager.gd` | JSON save/load (`user://node_realms_save.json`) with backward compatibility |
| `scripts/audio_manager.gd` | Procedural `AudioStreamWAV` synthesizer and 8-channel SFX mixer |
| `scenes/CampaignScene.tscn`, `scripts/campaign_scene.gd` | Legacy P2.2 standalone campaign scene (superseded by `MainHubScene.tscn`) |

---

## 3. Remaining Roadmap

### P3 Part 2 - Mobile UX Polish, Combat Readability & Player Retention
1. **In-Battle Readability & Bonus Tracking**:
   - Live match timer (`MM:SS`) in Battle HUD so players can track the `<90s` Fast Clear bonus, plus live indicator when `No Base Lost` is still intact.
   - Boss charge/HP clarity in Battle HUD (e.g., compact Boss Surge cooldown/warning bar on Level 15 / `Test Boss`).
2. **Android Safe Area & Tall-Screen Layout**:
   - Respect `DisplayServer.get_display_safe_area()` top/bottom insets in `MainHubScene` and `BattleScene` HUD bars for notched/punch-hole Android devices.
3. **Onboarding & Player Statistics**:
   - Lightweight, skippable first-match interactive tutorial hints (1-hand drag, Portal warp, Creature Skill).
   - Player Profile / Statistics dialog accessible from Main Hub (`Wins`, `Losses`, `Current Streak`, `Best Streak`, plus optional legacy `CampaignScene` cleanup decision).
4. **Post-Verdant Replayability (Optional P3)**:
   - Daily Seed Challenge or Endless Skirmish mode using `MapGenerator` with daily rewards.

### P4 - Google Play Store Readiness & Release
1. **App Identity & Store Assets**:
   - Custom adaptive Android launcher icons (generated/rendered into repo and wired in `export_presets.cfg`) and store screenshots/feature graphic.
2. **Signed Release Pipeline**:
   - Configure GitHub Secrets (`RELEASE_KEYSTORE_BASE64`, `RELEASE_KEYSTORE_USER`, `RELEASE_KEYSTORE_PASSWORD`) and verify signed `NodeRealms-release.aab` output.
3. **Play Store Compliance & Device QA**:
   - Verify target SDK, 64-bit ABI compliance, offline privacy policy (no data collection/no network permissions), back-button handling on Android, and multi-device touch QA.
