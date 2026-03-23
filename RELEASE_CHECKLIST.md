# Release Checklist (Google Play + App Store)

## 1) Flutter sanity checks
- Run `flutter clean`
- Run `flutter pub get`
- Run `flutter analyze`
- Run `flutter test`

## 2) Android (Google Play)
- Ensure `android/key.properties` exists locally (do not commit)
- Ensure release keystore file exists locally and matches `key.properties`
- Confirm `versionCode` increments for every release
- Build App Bundle: `flutter build appbundle --release`
- Upload `build/app/outputs/bundle/release/app-release.aab` to Play Console

## 3) iOS (App Store / TestFlight)
- Open `ios/Runner.xcworkspace` in Xcode (on macOS)
- Set Team and Signing for Runner target
- Verify bundle identifier and capabilities
- Archive: Product > Archive
- Upload archive to App Store Connect

## 4) Privacy and permissions
- Keep only permissions that are used by app features
- Fill Play Console Data safety form correctly
- Fill App Store privacy details correctly
- Ensure iOS usage descriptions in `Info.plist` match actual behavior

## 5) Pre-release smoke test
- Login/logout flow
- Add device / remove device
- WiFi setup flow and permission prompts
- Notification delivery
- Background/foreground transition
- App cold start and deep links (if any)

## 6) Rollout strategy
- Start with internal testing track
- Roll out staged (5% -> 20% -> 100%)
- Monitor crash-free users and ANR rate
