import Foundation

/// Replace these values with an iOS OAuth client from Google Cloud Console.
/// The YouTube Data API does not expose the personalized YouTube Home feed;
/// this app uses signed-in subscription activity instead.
enum YouTubeConfiguration {
    static let clientID = "YOUR_IOS_CLIENT_ID.apps.googleusercontent.com"
    static let redirectScheme = "com.googleusercontent.apps.YOUR_IOS_CLIENT_ID"
    static let scopes = ["https://www.googleapis.com/auth/youtube.readonly"]
}
