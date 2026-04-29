# SoulEcho

SoulEcho is a SwiftUI iOS + watchOS wellbeing app that combines HRV context, daily reflection, short check-ins, quotes, weather-aware prompts, and a 60-day insight dashboard.

The current product direction is not just "show health data." It helps users compare objective signals from Apple Watch, especially HRV, with subjective emotional state so they can stay calm, positive, and better understand their personal stress patterns.

## Current Features

### iOS App

- Home screen with a warm white-gold visual style and soft material cards.
- Daily quote experience with localized Chinese / English display.
- HRV status card that always stays visible on the home screen:
  - Shows latest HRV when HealthKit has data.
  - Features interactive states based on HealthKit permission:
    - **Connect Apple Health**: Prompts the user to authorize HealthKit if not determined.
    - **Refresh / Open Settings**: Guides the user if data is missing or permission might be turned off.
  - Shows a clear waiting state when running in simulator or before Health access/data is available.
- Weather recommendation card using lightweight weather context for outdoor reflection suggestions.
- Daily Reflection entry point:
  - Home screen stays compact.
  - Tapping `Start` / `Edit` slides up a native iOS sheet for daily reflection.
  - Saving slides the sheet back down.
  - Keyboard dismisses when tapping outside the text area or interacting with check-in choices.
- Daily 3-question check-in:
  - Physical Scan
  - Mental Pace
  - Emotional Filter
  - Each question uses A/B/C choices mapped to scores 1/2/3.
- Reflection History:
  - Saves one reflection per day.
  - Stores date, question, answer, HRV, quote, and check-in data.
  - Shows historical entries with HRV and check-in summaries.
- 60-Day Insight Dashboard:
  - Average HRV.
  - Subjective resilience score.
  - HRV / subjective alignment percentage.
  - HRV and subjective trend overlap chart.
  - Mind-body quadrant map.
  - Month-grouped 60-day check-in heatmap calendar.
  - Go-forward signals:
    - False Stress Indicator
    - Hidden Toll Indicator
    - RPM Warning

### watchOS App

- Watch companion target is present.
- HealthKit and notification-oriented architecture exists for watch-side care prompts.
- Reflect view and watch haptics managers are part of the app structure.
- **Quick Check-in**: Tap one of three emoji buttons (😌 Relaxed / 😐 Neutral / 😰 Tense) to record today's feeling directly from the wrist.
  - Haptic feedback and ✅ confirmation animation on selection.
  - Button changes to "Checked in ✓" after completion.
  - Data syncs to iPhone via App Group `UserDefaults` and merges into the `emotional` dimension of `DailyCheckIn`.

## Key Architecture

- SwiftUI app using the Observation framework (`@Observable`).
- HealthKit integration for HRV.
- UserDefaults-backed reflection persistence.
- String Catalog localization with Chinese / English copy.
- App Groups are configured for iPhone / Watch sharing.

## Important Files

- `SoulEcho/Features/Home/HomeView.swift`
  - Main home UI.
  - HRV card.
  - Daily Reflection launcher.
  - Sheet presentation for daily reflection.
  - Navigation to History and Insights.

- `SoulEcho/Core/Models/Reflection.swift`
  - Reflection models.
  - `DailyCheckIn`.
  - `CheckInChoice`.

- `SoulEcho/Core/Storage/ReflectionService.swift`
  - Daily question selection.
  - Save/update current day's reflection.
  - Persist/load reflection history.
  - Sync today's HRV into an existing reflection entry.

- `SoulEcho/Features/Reflection/ReflectionHistoryView.swift`
  - Reflection history list.
  - Per-entry HRV and check-in summaries.

- `SoulEcho/Features/Reflection/ReflectionInsightsView.swift`
  - 60-day dashboard.
  - Local chart rendering in SwiftUI.
  - Trend, quadrant map, heatmap calendar, and insight/action calculations.

- `SoulEcho/Core/Network/HealthService.swift`
  - HealthKit authorization.
  - Latest HRV fetch.
  - HRV status/color helpers.

## Build And Run

Open the project in Xcode:

```text
SoulEcho.xcodeproj
```

Recommended simulator target:

```text
iPhone 17, iOS 26.4
```

CLI build:

```bash
xcodebuild -project SoulEcho.xcodeproj -scheme SoulEcho -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

Simulator build/run in Codex uses the Build iOS Apps plugin with:

```text
project: SoulEcho.xcodeproj
scheme: SoulEcho
bundle id: com.ziyang.SoulEcho
```

## Notes For Testing

- Simulator usually does not have real HealthKit HRV samples, so the HRV card may show `-- ms`.
- Real HRV behavior should be tested on a physical iPhone paired with Apple Watch.
- Daily reflection and insight dashboard can be tested in simulator because reflection data is stored locally.
- The 60-day dashboard becomes more meaningful after multiple days of check-ins and HRV samples.

## Product Direction

SoulEcho is moving toward a "biofeedback vs. lived experience" loop:

- HRV tells the user what the body may be experiencing.
- Daily check-in tells the user how they feel subjectively.
- History and 60-day insights reveal whether the user's body and mind are aligned, disconnected, or showing early stress patterns.
