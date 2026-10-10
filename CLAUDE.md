## Project
Cyber Salvage Rush is a portrait-mode iOS sci-fi sorting puzzle. Players sort, route, merge, and manage futuristic salvage items moving through a workshop before the conveyor system overloads.

Full build plan: `docs/PLAN.md` (milestones M0–M9). Current progress and next steps: `docs/STATUS.md` — read it first when resuming.

## MVP Goal
Ship a polished, replayable 60–90 second single-player game loop with score chasing, upgrades, a daily challenge, and friend challenge codes.

## Tech Stack
- Swift 6+ (strict concurrency), Xcode 27, iPhone only, portrait, iOS 18.0+
- SwiftUI for menus, HUD, settings, progression, and onboarding
- SpriteKit for gameplay and effects (procedural neon art baked to textures; no live SKShapeNodes in gameplay)
- SwiftData for local persistence (behind a repository; never imported by SalvageCore)
- Game Center for leaderboards and achievements
- StoreKit 2 for the $2.99 Remove Ads non-consumable
- Google Mobile Ads (AdMob) + UMP consent + ATT
- No backend

## Layout
- `Packages/SalvageCore/` — pure Swift, value-type simulation, rules, tuning, codes, economy. No UIKit/SpriteKit/SwiftData.
- `App/` — SwiftUI shell, SpriteKit presentation (`Game/`), services (`Services/`).
- Bundle ID: `com.aliaamir.CyberSalvageRush`

## Commands
- The Xcode project is generated (gitignored). After adding/removing files or editing `project.yml`: `xcodegen generate`
- Core tests (fast, no simulator): `cd Packages/SalvageCore && swift test`
- All tests: `xcodebuild test -project CyberSalvageRush.xcodeproj -scheme CyberSalvageRush -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -derivedDataPath .build/xcode`
- Debug launch args: `-startRun` (straight into Endless), `-startTutorial` (straight into training)

## Core Loop
1. Salvage items enter the playfield on a conveyor.
2. Player drags items to matching bins (Recycler = standard, Vault = valuable, Containment = hazardous).
3. Correct sorting earns score and builds a combo.
4. Mistakes, expired hazards, or an overflowing buffer increase overload.
5. The run ends when the overload meter reaches 100%.
6. Score grants credits used for cosmetic and limited gameplay unlocks.

## Initial Gameplay Scope
- Portrait orientation only
- One primary board layout: conveyor → 4-slot buffer tray → 3 bins
- Three item types: standard, valuable, hazardous (distinct shapes, not just colors)
- One sorting action: drag item into matching destination
- Combo multiplier
- Increasing difficulty over time
- Score screen with retry in one tap
- Local high score persistence

## Progression
- Credits earned at the end of each run
- Unlockable workshop themes and cosmetic drone companions
- Small permanent upgrades, limited and balanced, Endless mode only
- No pay-to-win: the only purchase removes interstitial ads

## Daily Challenge & Challenge Codes
- Deterministic seed (stable hash of UTC date) produces the same item sequence for all players
- Daily/challenge runs have fixed rules: no permanent upgrades, no revives
- Friend multiplayer is asynchronous: a 6-char challenge code encodes (seed, config version); friends play the identical run and share back result codes. No real-time play, no backend.
- Game Center recurring leaderboard for the daily

## Monetization
- Rewarded ads (opt-in only): one revive per Endless run, or 2× credits on results
- Interstitials: never in tutorial/first session/first 3 runs; at most every 3rd run end, ≥120 s apart
- $2.99 non-consumable "Remove Ads" removes interstitials; rewarded stays available (opt-in)
- Debug builds must use Google test ad unit IDs

## Non-Goals for MVP
- No real-time multiplayer
- No account system
- No in-game chat
- No backend, remote configuration, or third-party analytics
- No generative AI during gameplay

## Engineering Rules
- Keep gameplay simulation deterministic: spawn schedule depends only on (seed, config), never on player actions
- Fixed 60 Hz simulation tick; rendering interpolates
- Never use Swift's `Hasher` for seeds (randomized per launch) — use `StableHash` (FNV-1a)
- `GameConfig.v1` is frozen once shipped; balance changes add a new version so old codes replay identically
- Separate game state from SpriteKit node presentation; the scene only reacts to `GameEvent`s
- Use value types for rules, scoring, item data, and run state
- Keep all tuning values centralized in `GameConfig`
- Build reusable components; avoid giant scene classes
- Add lightweight unit tests for score, combo, spawning, and failure conditions

## UX Requirements
- Tutorial must take less than 20 seconds
- Player should understand the goal without reading long text
- Retry should be available immediately after failure
- Prioritize haptics, clear audio feedback, readable effects, and responsive drag interactions
- Support Reduce Motion, Dynamic Type, Differentiate Without Color, Increased Contrast, VoiceOver on menus

## Definition of Done
A player can install the app, complete a tutorial, play repeated runs, earn a score, unlock one cosmetic item, and compete on a leaderboard without creating an account.
