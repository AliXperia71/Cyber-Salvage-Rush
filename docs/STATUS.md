# Status & Next Steps

Last updated: 2026-10-11. Full plan: `docs/PLAN.md`.

## Done
| Milestone | Commit | Notes |
|---|---|---|
| M0 Setup | `5716b59` | Own git repo, XcodeGen `project.yml`, CLAUDE.md |
| M1 Core sim | `5716b59` | `SalvageCore` package, 45 tests, balance bot median ≈ 75 s |
| M2 Presentation | `5716b59` | SpriteKit scene, baked neon textures, multi-touch drag, FX, haptics |
| M3 Shell + tutorial | `4be669a` | Menu, HUD, pause, results/retry, ghost-hand tutorial, Settings sheet |
| M4 Progression | see git log | SwiftData profile, credits, Workshop shop, 4 themes, 4 drones, Endless upgrades |

Playtested by the user with trackpad drag in the simulator. **Not yet tested on a physical iPhone.** M4 shop/purchase flow verified by tests and screenshots only, not hand-played yet.

## M4 notes (where things live)
- `App/Services/Persistence/Schema.swift`: `SchemaV1` (`PlayerProfile` singleton, `RunRecord`) + `SalvageMigrationPlan`. Any model change → add `SchemaV2` and a migration stage.
- `ProfileRepository`: the only SwiftData user. `recordRun(id:...)` is idempotent per run UUID; the first run of each UTC day earns the bonus.
- `GameContainerView` snapshots a `Loadout` (theme, drone, modifiers) per run, so mid-run profile changes never rebuild the scene.
- Themes apply to the SpriteKit board only; SwiftUI `Palette` is still Foundry.
- DEBUG launch arg `-freshProfile` uses an in-memory store (simulates a fresh install).
- `ScoreStore` is gone; best score comes from `RunRecord`.

## Next: M5 — Daily challenge + challenge codes
1. **DailyView**: today's best (filter `RunRecord.dayKey` + `modeKey == "daily"`), countdown, play button.
2. **ChallengeView**: create (random `ChallengeCode`, `ShareLink` text + `cybersalvage://challenge/CODE`), enter code (Crockford-tolerant field), results list.
3. **Result codes**: show own `ResultCode` on Results for challenge runs; paste friends' codes → `ChallengeEntry` model (adds `SchemaV2` + lightweight migration).
4. **Deep links**: `CFBundleURLTypes` for `cybersalvage`, `.onOpenURL` → router; parsing as a pure function with tests.
5. Exit: two simulators with the same code get identical belts.

## After M5
M6 Game Center → M7 StoreKit 2 + AdMob → M8 audio/accessibility/perf/icon → M9 release.

## Open items to remember
- Set `DEVELOPMENT_TEAM` in `project.yml` before building to a physical device.
- Xcode 27 doesn't offer the iOS 18.6 simulators as destinations. Test iOS 18 on a real device or install an older runtime before release.
- `GameConfig.v1` freezes at the first App Store release. After that, balance changes go into `v2`.
- Re-tune difficulty after playtesting on a phone (two-thumb play may beat the bot's pace).
