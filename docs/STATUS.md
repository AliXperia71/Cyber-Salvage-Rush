# Status & Next Steps

Last updated: 2026-10-11. Full plan: `docs/PLAN.md`.

## Done
| Milestone | Commit | Notes |
|---|---|---|
| M0 Setup | `5716b59` | Own git repo, XcodeGen `project.yml`, CLAUDE.md |
| M1 Core sim | `5716b59` | `SalvageCore` package, 45 tests, balance bot median ≈ 75 s |
| M2 Presentation | `5716b59` | SpriteKit scene, baked neon textures, multi-touch drag, FX, haptics |
| M3 Shell + tutorial | `4be669a` | Menu, HUD, pause, results/retry, ghost-hand tutorial, Settings sheet |
| M4 Progression | `3523982` | SwiftData profile, credits, Workshop shop, 4 themes, 4 drones, Endless upgrades |
| M5 Daily + challenges | (pending commit) | Daily best on menu/results, Friends challenges, result codes, `cybersalvage://` links, SchemaV2 |

Playtested by the user with trackpad drag in the simulator. **Not yet tested on a physical iPhone.** M4 shop/purchase flow verified by tests and screenshots only, not hand-played yet.

## M4 notes (where things live)
- `App/Services/Persistence/Schema.swift`: `SchemaV1` (`PlayerProfile` singleton, `RunRecord`) + `SalvageMigrationPlan`. Any model change → add `SchemaV2` and a migration stage.
- `ProfileRepository`: the only SwiftData user. `recordRun(id:...)` is idempotent per run UUID; the first run of each UTC day earns the bonus.
- `GameContainerView` snapshots a `Loadout` (theme, drone, modifiers) per run, so mid-run profile changes never rebuild the scene.
- Themes apply to the SpriteKit board only; SwiftUI `Palette` is still Foundry.
- DEBUG launch arg `-freshProfile` uses an in-memory store (simulates a fresh install).
- `ScoreStore` is gone; best score comes from `RunRecord`.

## M5 notes
- **Daily** has no separate screen (deliberate): the menu button shows today's best + countdown; Results shows "TODAY'S BEST". `ProfileRepository.dailyBests` is keyed by UTC day.
- `RunReward.best`/`isNewBest` are per context: all-time Endless, today's Daily, or per challenge code.
- `SchemaV2` adds `ChallengeEntry` + `ChallengeResult` (cascade). Unchanged models reuse their V1 classes. `MigrationTests` opens a real V1 store.
- `ChallengeRepository` owns challenges; the player's own best comes from `RunRecord.challengeCode`.
- `DeepLink` parses URLs and pasted text (link, result code, or challenge code). Links set `router.pendingLink`; the menu opens the Friends sheet when it's next visible, so a run is never interrupted. Leaving a challenge run returns to that challenge's page.
- Custom-scheme links aren't tappable in every messaging app, so share text leads with the code. Universal links need a domain; revisit in M9 (GitHub Pages).
- Not yet verified by hand: two simulators with the same code. Covered by core determinism tests + code round-trip tests.

## Next: M6 — Game Center
1. `GameCenterService` (`@MainActor`): silent `authenticateHandler` at launch; never blocks play.
2. Leaderboards `endless.highscore` (classic) and `daily.score` (recurring 24 h); submit from the `recordRun` path.
3. ~8 achievements (First Sort, Combo ×4, Survive 90 s, 50 Hazards, First Unlock, Daily Finisher, Challenge Sent, 10k Score) driven by `RunSummary` + repository events.
4. `GKAccessPoint` on the main menu; leaderboard buttons hidden when unauthenticated.
5. Needs: Game Center capability + App Store Connect leaderboard/achievement IDs, so `DEVELOPMENT_TEAM` must be set first.

## After M5
M6 Game Center → M7 StoreKit 2 + AdMob → M8 audio/accessibility/perf/icon → M9 release.

## Open items to remember
- Set `DEVELOPMENT_TEAM` in `project.yml` before building to a physical device.
- Xcode 27 doesn't offer the iOS 18.6 simulators as destinations. Test iOS 18 on a real device or install an older runtime before release.
- `GameConfig.v1` freezes at the first App Store release. After that, balance changes go into `v2`.
- Re-tune difficulty after playtesting on a phone (two-thumb play may beat the bot's pace).
