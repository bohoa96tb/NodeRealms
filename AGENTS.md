# AGENTS.md - Mandatory Workflow for NODE REALMS

This repository follows a strict **3-role sequential workflow** for every task. Never run parallel edits on the same files, and never skip a role before committing.

---

## Project Baseline (Must Always Hold)
- **Engine:** Godot 4.3 (`gl_compatibility`, GDScript only, `format=3` `.tscn`).
- **Target Device:** Android portrait `720x1280` (`canvas_items` / `expand`), one-handed touch controls, offline-first.
- **No External Assets/CDNs:** All visuals (`_draw()`, `Line2D`, `CPUParticles2D`, `Control`/`StyleBoxFlat`) and audio (`AudioStreamWAV`) must be self-contained in the repository.
- **Language Policy:** Game UI text must be clean English (Fantasy theme). Never introduce Chinese/Han characters anywhere in code, scenes, or UI.

---

## Sequential 3-Role Execution Model

Every change must pass through **Role 1 -> Role 2 -> Role 3** in strict order:

### Role 1 - Tech Lead & Game Designer
1. **Read Context First:** Always read `STATUS.md` and run `git status` before planning or editing.
2. **Single Small Task Rule:** Accept and scope **one small, self-contained task per turn**.
3. **Define Task Brief Clearly:** Before writing code, state:
   - **Goal:** Exact problem solved or feature added.
   - **Allowed Files:** Explicit list of files permitted to be created or modified.
   - **Acceptance Criteria:** Concrete, verifiable checks for completion.
4. **Escalation Rule:** Only pause to ask the user if the task involves major gameplay changes, architectural shifts, or Google Play release/signing decisions.

### Role 2 - Godot 4.3 Implementer (Gameplay / Map / AI / UI / Audio)
1. **Godot 4.3 Compliance:** Use strict Godot 4.3 GDScript syntax (`@export`, `@onready`, `create_tween()`, `Callable`, typed arrays without nested `Array[Array]`).
2. **Mobile-First Ergonomics:** Keep HUD and touch targets comfortable for one-handed portrait play (`720x1280`), avoiding overlap with `PLAY_AREA` or system gesture zones.
3. **Save Backward Compatibility:** Any new field in `SaveManager` must safely backfill when loading older `user://node_realms_save.json` files without erasing existing player progress.
4. **Scope Discipline:** Only modify files listed in Role 1's **Allowed Files**, keep all existing mechanics working, and avoid unnecessary external dependencies.

### Role 3 - QA & CI Gatekeeper (Mandatory Before Any Commit)
1. **Independent Diff Audit:** Review the entire `git diff` and modified files with a bug-hunting mindset:
   - Verify every `res://...` path exists in the repo.
   - Verify every `@onready` node path matches the exact hierarchy in its `.tscn` file.
   - Verify `load_steps` in every `.tscn` equals `1 + ext_resource + sub_resource`.
   - Verify Autoload entries in `project.godot` have no `class_name` naming conflicts.
   - Check for division by zero, freed/null node references (`is_instance_valid`), and timer/tween cleanup on scene transitions or map reloads.
   - Verify no Chinese/Han characters or external URLs/CDNs exist in project files.
2. **No Bypass Rule:** Never report a task complete if any check above was skipped or failed.
3. **Update & Sync:**
   - Update `STATUS.md` to reflect the newly completed work and next steps.
   - Run `git add`, `git commit`, and `git push origin main` so GitHub Actions (`.github/workflows/build-android.yml`) runs an Android APK build check.
   - Provide **3–5 concise bullet points** instructing the user how to quick-test the change on their Android phone.
