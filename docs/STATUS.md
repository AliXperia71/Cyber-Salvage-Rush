# Status & Next Steps

Last updated: 2026-10-10. Full plan: `docs/PLAN.md`.

## Done
| Milestone | Commit | Notes |
|---|---|---|
| M0 Setup | `5716b59` | Own git repo, XcodeGen `project.yml`, CLAUDE.md |
| M1 Core sim | `5716b59` | `SalvageCore` package, 45 tests, balance bot median ≈ 75 s |
| M2 Presentation | `5716b59` | SpriteKit scene, baked neon textures, multi-touch drag, FX, haptics |
| M3 Shell + tutorial | `4be669a` | Menu, HUD, pause, results/retry, ghost-hand tutorial, Settings sheet |

Playtested by the user with trackpad drag in the simulator. **Not yet tested on a physical iPhone.**

## Next: M4 — Progression (SwiftData + shop)
Goal: earn credits each run and unlock one cosmetic in the first session; persists across relaunch.

1. **SwiftData models** in `App/Services/Persistence/`, using a `VersionedSchema` from day one:
   - `PlayerProfile` (singleton): credits, owned cosmetic IDs, equipped theme/drone, `UpgradeLevels`, run count, last-run day key
   - `RunRecord`: mode, seed, score, duration, date
2. **`ProfileRepository`** wraps SwiftData. Keep it out of `SalvageCore`.
3. **Replace `ScoreStore`** (temporary UserDefaults best score) with a `RunRecord` query. `SettingsStore` stays in UserDefaults.
4. **Credits on results** via `Economy.credits(for:mode:firstRunToday:)`, using `DailySeed.dayKey` to detect the first run of the day.
5. **ShopView**: themes, drones, and upgrades from `EconomyConfig.standard.catalog` and `Economy.nextLevelCost`.
6. **Apply equipped items:**
   - Themes: add the remaining palettes to `Theme` (Neon Tide, Rust Belt, Void Chrome).
   - Drones: add `DroneNode`, a procedural sprite that reacts to combos.
   - Upgrades: pass `Economy.modifiers(for:mode:)` into `Simulation.endless(seed:modifiers:)`.
7. **Tests**: `ProfileRepository` with an in-memory container, purchase/equip rules, credits awarded once per run.

Exit criteria: from a fresh install, the player unlocks Neon Tide (150 credits) within about 2 runs, and it is still equipped after relaunch.

## After M4
M5 daily challenge screen + challenge/result codes UI + `cybersalvage://` deep links → M6 Game Center → M7 StoreKit 2 + AdMob → M8 audio/accessibility/perf/icon → M9 release.

## Open items to remember
- Set `DEVELOPMENT_TEAM` in `project.yml` before building to a physical device.
- Xcode 27 doesn't offer the iOS 18.6 simulators as destinations. Test iOS 18 on a real device or install an older runtime before release.
- `GameConfig.v1` freezes at the first App Store release. After that, balance changes go into `v2`.
- Re-tune difficulty after playtesting on a phone (two-thumb play may beat the bot's pace).
