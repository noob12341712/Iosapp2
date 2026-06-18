import Foundation

struct YouTubeVideo: Identifiable, Decodable {
    let id: String
    let title: String
    let channelTitle: String
    let thumbnailURL: URL?
    let publishedAt: Date?
    let videoID: String?

    var relativeAge: String {
        guard let publishedAt else { return "Recently" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: publishedAt, relativeTo: Date())
    }

    var watchURL: URL? {
        guard let videoID else { return nil }
        return URL(string: "https://www.youtube.com/watch?v=\(videoID)")
    }
}

struct ActivitiesResponse: Decodable {
    let items: [ActivityItem]
}

struct ActivityItem: Decodable {
    let id: String
    let snippet: ActivitySnippet
    let contentDetails: ActivityContentDetails?

    var video: YouTubeVideo? {
        let uploadVideoID = contentDetails?.upload?.videoId
        let recommendationVideoID = contentDetails?.recommendation?.resourceId.videoId
        let videoID = uploadVideoID ?? recommendationVideoID

        guard let videoID else { return nil }

        return YouTubeVideo(
            id: id,
            title: snippet.title,
            channelTitle: snippet.channelTitle,
            thumbnailURL: snippet.thumbnails.bestURL,
            publishedAt: snippet.publishedAt,
            videoID: videoID
        )
    }
}

struct ActivitySnippet: Decodable {
    let title: String
    let channelTitle: String
    let publishedAt: Date?
    let thumbnails: ThumbnailSet
}

struct ActivityContentDetails: Decodable {
    let upload: UploadDetails?
    let recommendation: RecommendationDetails?
}

struct UploadDetails: Decodable {
    let videoId: String
}

struct RecommendationDetails: Decodable {
    let resourceId: ResourceID
}

struct ResourceID: Decodable {
    let videoId: String?
}

struct ThumbnailSet: Decodable {
    let `default`: Thumbnail?
    let medium: Thumbnail?
    let high: Thumbnail?
    let standard: Thumbnail?
    let maxres: Thumbnail?

    var bestURL: URL? {
        maxres?.url ?? standard?.url ?? high?.url ?? medium?.url ?? `default`?.url
    }
}

struct Thumbnail: Decodable {
    let url: URL
}
