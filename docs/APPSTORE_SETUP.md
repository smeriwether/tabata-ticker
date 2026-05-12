# App Store and TestFlight Setup

This repo is configured to publish `Tabata Ticker` to TestFlight from GitHub Actions.

## Bundle IDs

Register these explicit App IDs in the Apple Developer portal:

| Target | Bundle ID |
| --- | --- |
| iOS app | `com.merimerimeri.tabataticker` |
| Watch companion | `com.merimerimeri.tabataticker.watchkitapp` |
| Live Activity extension | `com.merimerimeri.tabataticker.liveactivity` |

The Xcode project generator sets the Apple team to `8G4H6268W7`, matching the existing MenuMines signing setup.

## App Store Connect

Create one app record:

| Field | Value |
| --- | --- |
| Platform | iOS |
| Name | `Tabata Ticker` |
| Bundle ID | `com.merimerimeri.tabataticker` |
| SKU | `tabataticker` |

Because this app ships with an Apple Watch companion, fill in the required watchOS metadata and screenshots before external TestFlight testing or App Store submission.

## Apple Developer Assets

The release workflow creates temporary Apple Distribution signing assets and App Store provisioning profiles through the App Store Connect API, then cleans them up after the run.

## GitHub Secrets

Add these repository secrets to `smeriwether/tabata-ticker`:

| Secret | Description |
| --- | --- |
| `ASC_API_KEY_P8_BASE64` | Base64-encoded App Store Connect API key `.p8` |
| `ASC_KEY_ID` | App Store Connect API key ID |
| `ASC_ISSUER_ID` | App Store Connect issuer ID |

The App Store Connect API key must be allowed to manage certificates, identifiers, profiles, and app uploads. Admin access is the least ambiguous option for this first setup.

## Release

Tag-based release:

```sh
git tag v1.0.0
git push origin v1.0.0
```

Manual release:

1. Open GitHub Actions.
2. Run `Release to TestFlight`.
3. Enter a version such as `1.0.0`.

The workflow:

1. Runs `swift test`.
2. Archives the iOS app with the embedded watch companion.
3. Exports an App Store Connect `.ipa`.
4. Uploads the `.ipa` to App Store Connect/TestFlight.
5. Creates or updates the GitHub Release and attaches the `.ipa`.
