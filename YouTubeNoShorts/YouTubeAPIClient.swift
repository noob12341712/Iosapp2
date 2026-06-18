import Foundation

struct YouTubeAPIClient {
    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func fetchSubscriptionActivity(accessToken: String) async throws -> [YouTubeVideo] {
        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/activities")!
        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet,contentDetails"),
            URLQueryItem(name: "home", value: "true"),
            URLQueryItem(name: "maxResults", value: "25")
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw YouTubeAPIError.requestFailed
        }

        let activities = try decoder.decode(ActivitiesResponse.self, from: data)
        return activities.items.compactMap(\.video)
    }
}

enum YouTubeAPIError: LocalizedError {
    case requestFailed

    var errorDescription: String? {
        "YouTube request failed. Check that the YouTube Data API is enabled and your OAuth client is configured."
    }
}
