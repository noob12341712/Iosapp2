# YouTube sign-in setup

This project is wired for Google OAuth and the YouTube Data API, but it cannot ship with a real client ID. Before signing in from the app:

1. Create or open a Google Cloud project.
2. Enable the YouTube Data API v3.
3. Create an OAuth client for iOS.
4. Replace the placeholder values in `YouTubeConfiguration.swift`:
   - `clientID` should be the full value from Google, for example `510253802047-abc123.apps.googleusercontent.com`.
   - `redirectScheme` must be the reversed iOS URL scheme, for example `com.googleusercontent.apps.510253802047-abc123`.
5. Replace the same placeholder URL scheme in `Info.plist` with the exact same `redirectScheme` value.

Do not paste the full client ID into `CFBundleURLSchemes`. iOS URL schemes cannot start with a number, so using `510253802047-abc123.apps.googleusercontent.com` as the scheme can make the simulator show “Unable to Install”. Use `com.googleusercontent.apps.510253802047-abc123` instead.

The YouTube Data API does not expose the exact personalized YouTube Home feed used by the official YouTube app. This app loads signed-in subscription activity through the `activities` endpoint using the `youtube.readonly` scope.
