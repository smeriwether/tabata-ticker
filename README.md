# Tabata

Minimal native SwiftUI iOS and watchOS Tabata timer.

- Fixed workout: 8 rounds of 20 seconds work and 10 seconds rest.
- iPhone owns the timer.
- Watch mirrors the timer and sends start, pause, reset, and sound commands.
- Sounds beep during the final 5 work seconds and final 3 rest seconds.
- Watch pairs sound cues with haptics.

Build:

```sh
~/.local/share/mise/installs/ruby/3.3.4/bin/ruby Tools/generate_project.rb
xcodebuild -project Tabata.xcodeproj -target Tabata -configuration Debug -sdk iphonesimulator build CODE_SIGNING_ALLOWED=NO
xcodebuild -project Tabata.xcodeproj -target "Tabata Watch App" -configuration Debug -sdk watchsimulator build CODE_SIGNING_ALLOWED=NO
swift test
```
