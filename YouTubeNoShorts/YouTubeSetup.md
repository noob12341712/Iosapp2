# YouTube sign-in setup

This project is wired for Google OAuth and the YouTube Data API, but it cannot ship with a real client ID. Before signing in from the app:

1. Create or open a Google Cloud project.
2. Enable the YouTube Data API v3.
3. Create an OAuth client for iOS.
4. Replace the placeholder values in `YouTubeConfiguration.swift`:
   - `clientID`
   - `redirectScheme`
5. Replace the same placeholder URL scheme in `Info.plist`.

The YouTube Data API does not expose the exact personalized YouTube Home feed used by the official YouTube app. This app loads signed-in subscription activity through the `activities` endpoint using the `youtube.readonly` scope.
