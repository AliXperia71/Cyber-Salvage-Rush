# Cyber Salvage Rush: v1.0 Build & Ship Plan

## Context
`Cyber Salvage Rush/` contains only `CLAUDE.txt`, the game spec. This is the first app in the user's series of shipped iOS apps, so the target is a production-quality v1.0 on the App Store, not a prototype. The spec contradicted itself in two places, and the user settled both:
- **Multiplayer:** async **challenge codes**. A code encodes a seed and a ruleset, friends play the identical run, and they trade result codes. No backend and no real-time netcode.
- **Ads:** in v1.0 with AdMob. An opt-in **rewarded** ad gives a revive or 2× credits. An **interstitial** shows at most every 3rd run. A **$2.99 non-consumable** removes interstitials, and the rewarded ads stay available because they are opt-in.
- **Art:** **procedural neon**. Shapes are rendered in code into textures, UI uses SF Symbols, and sound effects come from a CC0 pack (Kenney.nl).

Environment: Xcode 27.0, Swift 6.4. Defaults chosen: **iPhone only, portrait, minimum iOS 18.0**, bundle ID `com.aliaamir.CyberSalvageRush`.

Definition of Done (from the spec): a player can install, finish the tutorial, play repeated runs, earn a score, unlock one cosmetic, and compete on a leaderboard, all without creating an account.

---

## 0. Repo & spec housekeeping
- The folder is currently untracked inside the parent `Personal Projects` git repo. Run `git init` inside `Cyber Salvage Rush/` so it is its own repo, with an Xcode `.gitignore` (DerivedData, xcuserdata, `.DS_Store`).
- Rename `CLAUDE.txt` to **`CLAUDE.md`** so Claude Code loads it automatically. Rewrite the Non-Goals so they no longer contradict the decisions above ("no real-time multiplayer" stays; "no ads/purchases" becomes "rewarded + capped interstitial + Remove Ads IAP"). Add the folder map and test commands below.

## 1. Architecture

There are two layers. A **pure-Swift simulation package** has no UIKit, SpriteKit, or SwiftData. A **thin app layer** presents it. This satisfies the spec's rules ("separate state from nodes", "value types", "centralized tuning", "no giant scene classes"), and the core tests run in about a second with `swift test`, without a simulator.

```
Cyber Salvage Rush/
  CLAUDE.md
  CyberSalvageRush.xcodeproj
  Packages/SalvageCore/
    Package.swift                      // swift-tools 6.x, strict concurrency, iOS 18 / macOS 15
    Sources/SalvageCore/
      Config/GameConfig.swift          // ALL tuning values; versioned: GameConfig.v1 (immutable once shipped)
      Random/SeededGenerator.swift     // SplitMix64 / xoshiro256** : RandomNumberGenerator
      Random/StableHash.swift          // FNV-1a (never Swift's Hasher: it's randomized per launch)
      Model/Item.swift, Bin.swift, ItemKind.swift (standard | valuable | hazardous)
      Model/RunState.swift, RunMode.swift (endless | daily | challenge | tutorial)
      Simulation/Simulation.swift      // mutating step(inputs:) -> [GameEvent], fixed 60 Hz tick
      Simulation/SpawnSchedule.swift   // precomputed from seed+config, independent of player actions
      Simulation/ScoreEngine.swift, ComboTracker.swift, OverloadMeter.swift, DifficultyCurve.swift
      Simulation/GameEvent.swift, PlayerInput.swift, RunSummary.swift
      Modes/DailySeed.swift            // seed = FNV1a("CSR-daily-v1-" + UTC yyyyMMdd)
      Modes/ChallengeCode.swift        // 6-char Crockford base32 <-> (seed, configVersion) + checksum
      Modes/ResultCode.swift           // encodes (challenge, score) + checksum for sharing back
      Progression/Economy.swift        // credits formula, upgrade costs/effects, unlock catalog
    Tests/SalvageCoreTests/            // Swift Testing (@Test)
  App/
    CyberSalvageRushApp.swift          // @main, SwiftData container, service wiring, GC auth
    Shell/AppRouter.swift, RootView.swift
    Screens/ MainMenuView, GameContainerView (SpriteView + HUD overlay), HUDView, ResultsView,
             ShopView (themes/drones/upgrades), DailyView, ChallengeView (create/enter/results),
             SettingsView, TutorialOverlay
    Game/
      GameScene.swift                  // thin: owns layers, forwards touches, applies events
      GameController.swift             // @MainActor bridge: fixed-step accumulator, sim <-> scene, event fan-out
      Nodes/ ItemNode, BinNode, ConveyorNode, BufferTrayNode, DroneNode
      Input/DragController.swift       // hit-test with enlarged touch radius, lift/snap, drop resolution
      Effects/ EffectsDirector.swift   // particles, flashes, screen shake (Reduce Motion aware)
      Textures/ProceduralTextureFactory.swift // SKShapeNode -> SKView.texture(from:) once, cached per theme
    Services/
      Persistence/ Models.swift (SwiftData @Model), ProfileRepository.swift
      GameCenterService.swift, StoreService.swift (StoreKit 2), AdService.swift (AdMob + UMP + ATT)
      AudioService.swift (AVAudioEngine, preloaded buffers), HapticsService.swift, SettingsStore.swift
    Resources/ Assets.xcassets, AppIcon (Icon Composer), Sounds/*.caf, PrivacyInfo.xcprivacy,
               Products.storekit, Info.plist (portrait only, GADApplicationIdentifier, SKAdNetworkItems,
               ITSAppUsesNonExemptEncryption = NO)
  CyberSalvageRushTests/               // app-level: repository, StoreService w/ StoreKitTest, code deep links
  docs/privacy-policy.md, docs/support.md   // host via GitHub Pages (required URLs)
```

**Key design rules**
- `Simulation` is a value type. Inputs are `.grab(itemID)`, `.drop(itemID, binID)`, and `.release(itemID)`. Outputs are `GameEvent`s (`spawned`, `sorted(points, comboTier)`, `missorted`, `missed`, `hazardExpired`, `overloadChanged`, `comboBroken`, `bufferOverflow`, `runEnded(RunSummary)`). The scene and services only *react* to events, so audio, haptics, FX, achievements, and ads never reach into the simulation.
- **Determinism:** the spawn sequence (kind, lane, time) is precomputed from `(seed, config)` and never depends on what the player does. Two players with the same daily or challenge seed therefore see an identical belt. The simulation steps at a fixed 1/60 s, while rendering runs at up to 120 Hz (ProMotion) using an accumulator.
- **Swift 6 concurrency:** core types are `Sendable`. The scene, controller, and services are `@MainActor`, and StoreKit and GameKit calls use async/await.
- **Performance:** never render live `SKShapeNode`s in gameplay. Bake the procedural shapes and glow halos into textures once per theme and use `SKSpriteNode` with additive blending. Pool item nodes.

## 2. Gameplay design (MVP)
- **Board:** a conveyor runs across the top two-thirds of the screen and feeds into a **buffer tray** of 4 slots near the bottom. Three bins sit along the bottom edge, within thumb reach: **Recycler** (standard), **Vault** (valuable), and **Containment** (hazardous).
- **Readability without color:** each kind has its own shape and icon (standard = hex, valuable = diamond, hazardous = triangle with ☢), so the game works with Differentiate Without Color and for colorblind players.
- **Rules:**
  - A correct drop gives `basePoints[kind] × comboMultiplier`.
  - Combo tiers are ×1, ×2 at 5 sorts, ×3 at 12, and ×4 at 25. A wrong bin breaks the combo.
  - An item that reaches the end of the belt goes into the buffer. If the buffer is full, overload rises every second.
  - A hazardous item has a fuse. If it expires anywhere, it adds a large overload spike.
  - Overload increases: missort +12, hazard expiry +20, buffer overflow +6/s. A correct sort relieves 1.5. The run ends at 100%.
- **Difficulty curve:** belt speed, spawn interval, and hazard ratio all ramp with run time, and all values live in `GameConfig`. The tuning target is a **median run of about 75 s** for a decent player. A balance test enforces this (see §8).
- **Run end:** the Results screen shows the score, best score, and credits earned. **Retry** is the largest button and needs one tap. A rewarded ad offers a **revive** (overload reset to 50%, once per run, endless mode only) or **2× credits**.
- **Tutorial (under 20 s):** three scripted items, one per bin. An animated ghost hand shows the drag, captions are 2–4 words ("Drag to matching bin"), and the run goes live right after. It can be skipped and replayed from Settings.

## 3. Progression (no pay-to-win)
- **Credits** = `score / 50`, rounded, plus a small first-run-of-the-day bonus. All values are in `Economy`.
- **Cosmetics:** 4 workshop themes (palette and texture swaps, which are cheap with baked textures) and 4 drone companions (procedural sprites that hover and react to combos). One of each is free, and the first unlock costs about 2–3 runs' worth of credits, so the Definition of Done is reachable in the first session.
- **Upgrades:** 3 upgrades × 3 levels, all small. Examples: buffer +1 slot, hazard fuse +8%, and a combo shield that forgives one missort per run. They apply **only in Endless**. Daily and Challenge runs use fixed rules with no upgrades.

## 4. Daily challenge & challenge codes
- **Daily:** the seed is a stable hash of the UTC date. Rules are fixed, there are no upgrades or revives, and the player gets unlimited attempts with the best score counting. Scores post to a **Game Center recurring leaderboard** (24 h period). The screen shows a countdown to the next daily.
- **Challenge codes:**
  - A host taps "Create Challenge" and gets a code like `K7Q2XM`. The code encodes 25 bits of seed, the config version, and a 5-bit checksum.
  - The host shares it through `ShareLink` as text plus a `cybersalvage://challenge/K7Q2XM` deep link (a custom URL scheme, so no domain is needed).
  - A friend opens the link or types the code and plays the identical run under Daily rules.
  - Results go back as a short **result code** (or a share text containing it). Pasting result codes builds a local leaderboard for that challenge, stored in SwiftData.
- **Fair-play note:** with no backend, codes are typo-proof but not cheat-proof. That is acceptable for friends. The global competition happens on the Game Center leaderboards.
- **Versioning:** `GameConfig.v1` is frozen once it ships. A future balance change adds `v2`, so old codes still replay identically.

## 5. Persistence (SwiftData)
- `PlayerProfile` (singleton) stores credits, owned/equipped cosmetic IDs, upgrade levels, tutorial-done flag, run count, last interstitial time, and a cached `adsRemoved` flag.
- `RunRecord` stores mode, seed, score, duration, and date. High scores come from querying it.
- `ChallengeEntry` stores the code, your score, and the friends' decoded results.
- SwiftData stays behind `ProfileRepository` so the core package never imports it. Use a lightweight `VersionedSchema` from day one so future migrations are painless.

## 6. Game Center
- Authenticate silently at launch with `GKLocalPlayer.local.authenticateHandler`. Never block play, and hide leaderboard UI when the player is unauthenticated.
- Leaderboards: `endless.highscore` (classic, all-time) and `daily.score` (recurring, 24 h).
- About 8 achievements, such as First Sort, Combo ×4, Survive 90 s, Sort 50 Hazards, First Unlock, Daily Finisher, Challenge Sent, and 10k Score.
- Add `GKAccessPoint` on the main menu and `GameCenterService` hooks into `runEnded` events. Test in the Game Center sandbox.

## 7. Monetization
- **StoreKit 2:** one non-consumable product, `com.aliaamir.CyberSalvageRush.removeads`, priced at $2.99.
  - `StoreService` loads products, buys them, and listens to `Transaction.updates`. At launch it checks `Transaction.currentEntitlements` and verifies each transaction.
  - A **Restore Purchases** button is required for App Review.
  - Use `Products.storekit` for local testing and `StoreKitTest` for unit tests.
- **AdMob** (Google Mobile Ads SDK via SPM), wrapped in an `AdService` protocol with a no-op implementation for tests and the simulator:
  - **Consent:** the Google UMP SDK handles GDPR/US-state consent at first launch. The **ATT** prompt appears *after the first completed run*, not at cold start. If the player denies tracking, they get non-personalized ads.
  - **Interstitial policy:** never during the tutorial, the first session, or the first 3 runs. After that, at most every 3rd run end with at least 120 s between ads. Never when `adsRemoved` is true. Ads load ahead of time and are never shown mid-run.
  - **Rewarded:** only when the player taps an offer on the Results screen. These remain after Remove Ads.
  - **Setup:** debug builds use Google's **test ad unit IDs** so the AdMob account doesn't get banned. Fill `SKAdNetworkItems` in Info.plist and complete the privacy manifest and the App Store privacy label (Identifiers, Usage Data, and Diagnostics, linked to third-party advertising). Set the age rating to account for ads.
- **Account prerequisites:** sign the **Paid Apps Agreement** and complete banking and tax in App Store Connect early, because IAP won't work in TestFlight without them. Also create an AdMob account and app and set up `app-ads.txt` on the GitHub Pages domain.

## 8. Testing
**SalvageCore** uses Swift Testing and runs with `swift test` in `Packages/SalvageCore`:
- **Score and combo:** tier thresholds, multiplier math, and that a missort breaks the combo.
- **Spawning:** the same seed produces a byte-identical `SpawnSchedule` (checked against a golden snapshot of the first 50 spawns), different seeds produce different schedules, the difficulty ramp is monotonic, and the hazard ratio stays within bounds.
- **Failure:** overload clamps to 0…100, a `runEnded` event fires exactly once at 100%, buffer overflow accrues per second, and hazard expiry produces a spike.
- **Codes:** encode→decode round-trips for random seeds, single-character typos are rejected by the checksum, and Crockford ambiguous characters are handled (O→0, I/L→1).
- **Daily seed:** fixed dates map to fixed seeds, and boundaries use the UTC date.
- **Economy:** the credits formula is correct and upgrades are ignored in daily and challenge modes.
- **Balance bot:** a scripted player with a 350 ms reaction time and a 5% error rate runs 200 seeds. The test asserts that the median run length is between 60 and 90 s, which guards the spec's run-length target against tuning regressions.

**App tests** (`xcodebuild test -scheme CyberSalvageRush -destination 'platform=iOS Simulator,name=iPhone 17'`) cover:
- ProfileRepository with an in-memory SwiftData container
- StoreService purchase and restore through StoreKitTest
- Deep-link parsing
- The interstitial-frequency policy as a pure function

## 9. UX, accessibility, juice
- **Drag feel:** touch begins pick up the nearest item within a 44 pt radius. The item lifts with a slight scale-up and shadow and follows the finger with an offset so it isn't hidden under the thumb. Bins highlight as drop targets, and a near-miss drop snaps into the bin.
- **Haptics:** `UIImpactFeedbackGenerator`, prepared ahead of time, for grab, a successful sort, and combo tier-ups. An error notification haptic fires on missorts.
- **Audio:**
  - `AVAudioEngine` with preloaded buffers.
  - The combo pitch rises with each tier.
  - Uses the `.ambient` session category so it respects the silent switch and mixes with the user's music.
  - Separate SFX and music toggles.
- **Reduce Motion:** no screen shake, fewer particles, and crossfades instead of zooms.
- **Other accessibility:**
  - Dynamic Type and VoiceOver labels on all SwiftUI screens.
  - Differentiate Without Color support through shapes.
  - Increased Contrast support through palette variants.
  - An optional **Assist Mode** (slower belt) that is excluded from leaderboards.
- **Performance budget:** 60 fps minimum on an iPhone 12-class device, and 120 Hz on ProMotion. Verify with the SpriteKit `showsFPS`/node count and an Instruments Time Profiler pass.

## 10. Milestones (in order; each ends playable or testable)
| # | Milestone | Exit criteria |
|---|---|---|
| M0 | Repo, Xcode project, SalvageCore package, CLAUDE.md | App launches to a blank menu, and `swift test` passes |
| M1 | Core simulation + tests (headless) | All §8 core tests pass, including the balance bot |
| M2 | SpriteKit presentation + drag + baked neon textures | A full run is playable on device at 60+ fps |
| M3 | SwiftUI shell: menu, HUD, results, one-tap retry, tutorial | Install, tutorial, run, and retry loop in under 20 s of tutorial |
| M4 | SwiftData + credits, shop, themes/drones/upgrades | Unlock one cosmetic in the first session, and it persists across relaunch |
| M5 | Daily challenge + challenge/result codes + deep links | Two devices with the same code get identical belts |
| M6 | Game Center leaderboards + achievements | Scores appear in the sandbox leaderboards |
| M7 | StoreKit 2 Remove Ads + AdMob (UMP, ATT, test IDs) | Purchase and restore work in sandbox, and ad caps behave per policy |
| M8 | Audio, haptics, accessibility, perf, app icon (Icon Composer) | Accessibility checklist passes, and the Instruments run is clean |
| M9 | Release: App Store Connect listing, privacy policy, screenshots (6.9"), TestFlight external beta, submission | Approved and live |

**M9 release checklist:**
- Bundle ID with the Game Center and In-App Purchase capabilities
- App Store Connect record, with the IAP attached to the first submission
- Privacy policy and support URLs
- Privacy label and age rating
- Export compliance key
- Review notes explaining the challenge codes and how to test Remove Ads
- Production AdMob unit IDs, switched on only in Release builds
- A final pass on a physical device on the oldest supported iOS version

## 11. Post-launch (not v1.0)
- v1.1 ideas: live Game Center matches using join codes (a `playerGroup` derived from the code), more item kinds and bins, weekly events, and Remote Config. Before adding any of these, validate retention with App Store Connect analytics, since v1.0 has no third-party analytics.

## Verification (end-to-end)
1. Run `swift test` in `Packages/SalvageCore`. All core, determinism, code, and balance tests must be green.
2. Run `xcodebuild test` on the iOS 18 and current simulators to cover the app tests.
3. Walk through the Definition of Done on a physical iPhone from a fresh install: tutorial, three runs, unlock one cosmetic, then relaunch and confirm it persisted. Then post a score and see it in the Game Center sandbox leaderboard, all with no account creation.
4. Determinism check: enter the same challenge code on the simulator and on the device, and confirm the item sequence matches.
5. Monetization: buy and restore with a StoreKit sandbox tester. Confirm interstitials never appear in the first 3 runs and then follow the cap. Confirm the revive and 2× rewards are granted.
6. Turn on Reduce Motion, the largest Dynamic Type size, VoiceOver on menus, and Differentiate Without Color, and confirm each behaves as specified.
7. Run a TestFlight external beta with at least 5 testers before submitting.
