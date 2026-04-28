# SoulEcho Project Status

Last updated: 2026-04-27

This file is meant for editors/agents such as Cursor, Antigravity, or Codex to quickly understand the current project state and continue work without rediscovering the codebase.

## Current Goal

SoulEcho is an iOS + watchOS wellbeing app focused on helping users compare Apple Watch HRV with subjective daily feelings. The latest work added a daily reflection system, history, and a 60-day insight dashboard.

The product should feel calm, premium, warm, and practical. Avoid turning the home screen into a long form. The current interaction model is:

1. Home shows quote, HRV, Daily Reflection launcher, and weather suggestion.
2. Daily Reflection opens as a slide-up sheet.
3. History and Insights are separate navigation destinations.

## Recently Implemented

### Daily Reflection

Files:

- `SoulEcho/Core/Models/Reflection.swift`
- `SoulEcho/Core/Storage/ReflectionService.swift`
- `SoulEcho/Features/Home/HomeView.swift`

Implemented:

- One daily reflection entry per date.
- Daily prompt chosen from HRV state:
  - low
  - balanced
  - restored
  - unknown
- Reflection text answer.
- Quote snapshot on save.
- HRV snapshot on save.
- Update existing same-day entry instead of creating duplicates.
- UserDefaults persistence.
- Keep up to 90 recent entries.

### Daily 3-Question Check-In

Model:

- `DailyCheckIn`
- `CheckInChoice`

Questions:

- Physical Scan
- Mental Pace
- Emotional Filter

Choices:

- A = 1 point
- B = 2 points
- C = 3 points

The check-in supports partial completion. Saving is allowed if the user either enters text or selects at least one check-in choice.

### HealthKit Access State Management

Files:

- `SoulEcho Watch App/ContentView.swift`
- `SoulEcho Watch App/Managers/HealthObserverManager.swift`
- `SoulEcho/Core/Network/HealthService.swift`
- `SoulEcho/Features/Home/HomeView.swift`

Implemented:

- Robust `HealthAccessState` enum (`.notDetermined`, `.loading`, `.available`, `.noRecentSample`, `.unavailable`, `.permissionPossiblyOff`).
- Interactive UI to prompt users to "Connect Apple Health", "Refresh", or "Open Settings" when HRV data is missing.
- Prevents redundant HealthKit authorization prompts using App Group `UserDefaults` (`soulEcho_health_permission_requested`).
- Localized dynamic messages to clearly explain to the user why data might be missing and how to resolve it.

### Home Screen Changes

File:

- `SoulEcho/Features/Home/HomeView.swift`

Implemented:

- HRV card is always visible.
  - If HealthKit has no HRV, it shows `-- ms` and an explanatory waiting state.
- Daily Reflection no longer occupies the full home screen.
- Home has a compact `ReflectionLauncherCard`.
- `Start` / `Edit` opens `DailyReflectionSheet`.
- Sheet uses native iOS slide-up/down presentation.
- Saving dismisses the sheet.
- Keyboard dismiss behavior is wired through `@FocusState`.
- Reflection card includes:
  - `History`
  - `Insights`
  - `Start` / `Edit`

### Reflection History

File:

- `SoulEcho/Features/Reflection/ReflectionHistoryView.swift`

Implemented:

- Shows saved entries in reverse chronological order.
- Displays:
  - Date
  - HRV / No HRV
  - Question
  - Check-in summary
  - Answer text
  - Quote snapshot

### 60-Day Insight Dashboard

File:

- `SoulEcho/Features/Reflection/ReflectionInsightsView.swift`

Implemented:

- 60-day window based on today's date.
- Summary metrics:
  - Average HRV
  - Subjective resilience
  - Data alignment
- Trend overlap chart:
  - HRV line
  - Subjective feeling line/bars
- Mind-body quadrant map:
  - Restored
  - Hidden Toll
  - False Stress
  - Recovery
- Month-grouped heatmap calendar:
  - Real month headers.
  - Weekday row.
  - Leading blanks based on actual weekday.
  - Daily color based on subjective score.
- Go-forward signals:
  - False Stress Indicator
  - Hidden Toll Indicator
  - RPM Warning

## Current Data Model

`ReflectionEntry`

- `id`
- `dateKey`
- `question`
- `answer`
- `checkIn`
- `hrvValue`
- `quoteContent`
- `quoteAuthor`
- `createdAt`
- `updatedAt`

`DailyCheckIn`

- `physical`
- `mental`
- `emotional`
- `completedCount`
- `hasAnySelection`
- `isComplete`
- `averageScore`

## Known Behavior

- Simulator usually has no HRV samples, so HRV-dependent fields may show `--`.
- Insight dashboard still works with reflection-only data, but data alignment and HRV trend need entries with both HRV and check-in scores.
- The dashboard is intentionally local and deterministic. No backend or AI generation is used yet.
- `ReflectionService` persists to UserDefaults using key `reflection_entries`.

## Build Verification

Verified with Build iOS Apps plugin:

```text
scheme: SoulEcho
simulator: iPhone 17
bundle id: com.ziyang.SoulEcho
extra args: CODE_SIGNING_ALLOWED=NO
```

Recent verification:

- iOS Simulator build succeeded.
- App launched successfully.
- Home screen shows HRV card and Reflection launcher.
- Insights navigation opens the dashboard.
- Daily Reflection sheet opens and saves/dismisses.

## Important Implementation Notes

- The project uses Xcode file-system synchronized groups, so new Swift files under `SoulEcho/...` are picked up without manual pbxproj source entries.
- Do not commit `SoulEcho.xcodeproj/project.xcworkspace/xcuserdata/.../UserInterfaceState.xcuserstate`; it is local Xcode UI state.
- Keep UI consistent with the existing white/gold material theme.
- Avoid making the home screen a long form. Put heavier workflows in sheets or pushed screens.
- Prefer native SwiftUI views and simple local calculations before adding dependencies.

## Suggested Next Work

High-value next steps:

- Add seeded demo reflection data for simulator-only testing of the 60-day dashboard.
- Add a detail sheet when tapping a day in the heatmap.
- Add a small explanatory legend for heatmap colors.
- Add export/share for 60-day insights.
- Add HealthKit historical HRV fetch, not only latest HRV.
- Add reminder/notification to complete daily reflection.
- Improve watchOS sync so watch-side HRV context can prefill iOS reflection entries.

## Git Notes

The current working branch is `main`, tracking `origin/main`.

When committing, include functional Swift files and docs, but avoid local Xcode state files.
