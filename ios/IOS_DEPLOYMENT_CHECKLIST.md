# iOS Deployment Checklist

This repo can target iOS, but you still need to finish Apple account, signing, and Clerk production setup before shipping.

## What was already patched in the repo

- `ios/Podfile` now explicitly targets iOS 13.0.
- `ios/Runner.xcodeproj/project.pbxproj` now reads the app bundle ID and team ID from xcconfig values instead of hardcoding them in the target.
- `ios/Runner/Info.plist` now reads the app display name from xcconfig.
- `ios/Flutter/AppConfig.defaults.xcconfig` provides safe defaults.
- `ios/Flutter/AppConfig.xcconfig.example` shows the local values you should create and fill.

## Step 1: Create your local iOS app config file

What to do:

1. Copy `ios/Flutter/AppConfig.xcconfig.example` to `ios/Flutter/AppConfig.xcconfig`.
2. Replace the placeholder values.

What each value means:

- `APP_DISPLAY_NAME`: The app name shown on the iPhone home screen.
- `APP_BUNDLE_IDENTIFIER`: Your permanent iOS app ID, for example `com.anasa.simonsays`.
- `APPLE_DEVELOPMENT_TEAM`: Your Apple Team ID, a 10-character string.

Where to get it:

- Team ID: https://developer.apple.com/help/glossary/team-id/
- Apple says you can find it in your Apple Developer account under Membership details.

## Step 2: Make sure you have an Apple Developer Program account

What to do:

1. Sign in with your Apple account.
2. Confirm that the account is enrolled in the Apple Developer Program if you plan to ship through TestFlight or the App Store.

Where to get it:

- Account basics: https://developer.apple.com/help/account/get-started/about-your-developer-account/

Why this matters:

- You can test locally without full App Store release setup, but App Store/TestFlight distribution requires a paid Apple Developer Program membership.

## Step 3: Choose your final bundle identifier carefully

What to do:

1. Pick a reverse-DNS identifier you control, such as `com.yourname.simonsays`.
2. Put that exact value into `APP_BUNDLE_IDENTIFIER`.
3. Use the exact same value later in App Store Connect and any auth provider dashboards.

Where to get guidance:

- Apple distribution prep: https://developer.apple.com/documentation/xcode/preparing-your-app-for-distribution/
- Apple App information reference: https://developer.apple.com/help/app-store-connect/reference/app-information/app-information

Important:

- After you upload your first build, changing the bundle identifier becomes painful or impossible for the same app record. Treat it as permanent.

## Step 4: Open the project on a Mac and finish signing in Xcode

What to do:

1. Open `ios/Runner.xcworkspace` in Xcode on macOS.
2. Select the `Runner` target.
3. Open `Signing & Capabilities`.
4. Turn on `Automatically manage signing`.
5. Select your Apple team.
6. Confirm the bundle identifier matches `APP_BUNDLE_IDENTIFIER`.

Where to get guidance:

- Apple distribution prep: https://developer.apple.com/documentation/xcode/preparing-your-app-for-distribution/

Notes:

- This repo now gives Xcode a place to read the Team ID from, but you still need to sign in to Xcode with your Apple account on a Mac.
- If automatic signing works, Xcode usually handles the development certificate and provisioning profile for you.

## Step 5: Create the app record in App Store Connect

What to do:

1. Go to App Store Connect.
2. Create a new app record.
3. Enter the app name, primary language, SKU, and bundle ID.
4. Use the same bundle ID from `APP_BUNDLE_IDENTIFIER`.

Where to do it:

- Add a new app: https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/

Important:

- The bundle ID in App Store Connect must match the Xcode project exactly.

## Step 6: Confirm the version and build numbers you want

What the repo currently does:

- Flutter `pubspec.yaml` sets `version: 1.0.0+1`.
- iOS reads those values into `CFBundleShortVersionString` and `CFBundleVersion`.

What to do:

1. Update `pubspec.yaml` before each release.
2. Use the format `marketing_version+build_number`, for example `1.0.1+2`.

Notes:

- `1.0.1` is the user-facing version.
- `2` is the internal build number and must increase for each uploaded build.

## Step 7: Verify Clerk production setup for iOS shared auth

Your app code uses Clerk auth and shared backend APIs on iOS, so this needs review before release.

What to do:

1. In the Clerk Dashboard, verify Native API is enabled.
2. Add your iOS app under Native Applications.
3. Use your iOS app's App ID Prefix and Bundle ID there.
4. If you use OAuth providers like Google, allowlist the mobile redirect URL.
5. For production social sign-in, configure provider-specific custom OAuth credentials in Clerk where required.

Where to do it:

- Clerk iOS quickstart: https://clerk.com/docs/ios/getting-started/quickstart
- Clerk OAuth social connections for iOS: https://clerk.com/docs/ios/guides/configure/auth-strategies/social-connections/overview

Important Clerk details from the docs:

- Clerk says native apps require allowlisting redirect URLs for OAuth.
- Clerk says the default mobile redirect is `{bundleIdentifier}://callback`.

Repo-specific warning:

- I did not find `CFBundleURLTypes` or Associated Domains configuration in the current iOS files.
- That does not prove runtime failure, but it is the first place I would verify on macOS when testing Clerk-based sign-in on a real iPhone.

## Step 8: Decide whether production will use local auth or the shared backend

What to do:

1. Build the shipped iOS app with:
   `--dart-define=API_BASE_URL=https://YOUR_SERVER_DOMAIN`
   `--dart-define=CLERK_PUBLISHABLE_KEY=pk_live_...`

Repo-specific notes:

- `lib/api/api_client.dart` already rejects insecure non-local HTTP endpoints.
- For production, your API must use HTTPS.

## Step 9: Run a real iOS smoke test on a Mac

What to do:

1. Run the app in Xcode on an iPhone simulator.
2. Run it on a physical iPhone.
3. Test:
   - launch
   - sign in / sign up
   - Google sign-in if enabled
   - score save flow
   - settings persistence
   - sign out

Why this matters:

- I can verify repo structure from here, but I cannot run `flutter build ios` or an Xcode archive on Windows.

## Step 10: Fix the repo's current test mismatch before calling it release-ready

Current repo status from local verification:

- `flutter analyze` passes.
- `flutter test` currently fails because some tests still expect the old auth screen text `Sign in or create a shared player account`.

Files involved:

- `test/auth_flow_test.dart`
- `test/resilience_states_test.dart`
- `lib/main.dart`

Recommendation:

- Fix those test expectations before treating the app as release-ready.

## Step 11: Create the archive and upload from macOS

What to do:

1. Open the workspace in Xcode.
2. Choose a generic iOS device or a connected real device.
3. Archive the app.
4. Validate the archive.
5. Upload it to App Store Connect.

Where to get Apple guidance:

- Apple distribution prep: https://developer.apple.com/documentation/xcode/preparing-your-app-for-distribution/
- Provisioning profile help: https://developer.apple.com/help/account/provisioning-profiles/create-an-app-store-provisioning-profile/

## Minimal order to do this with the least confusion

1. Fill `ios/Flutter/AppConfig.xcconfig`.
2. Open the project on a Mac.
3. Set signing in Xcode.
4. Create the App Store Connect app record.
5. Verify Clerk Native Applications and OAuth redirect settings.
6. Test on simulator and real device.
7. Fix remaining Flutter test mismatches.
8. Archive and upload.
