import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = YouTubeFeedViewModel()
    private let videos = Video.sampleVideos
    private let chips = ["All", "Music", "Gaming", "Podcasts", "Live", "Recently uploaded"]

    var body: some View {
        TabView {
            NavigationStack {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 22) {
                        chipScroller

                        if viewModel.isSignedIn {
                            signedInFeed
                        } else {
                            SignInPrompt {
                                Task { await viewModel.signInAndLoadFeed() }
                            }

                            ForEach(videos) { video in
                                VideoCard(video: video)
                            }
                        }
                    }
                    .padding(.bottom, 24)
                }
                .background(Color(.systemBackground))
                .safeAreaInset(edge: .top) {
                    ModernHeader(isSignedIn: viewModel.isSignedIn) {
                        Task { await viewModel.signInAndLoadFeed() }
                    }
                }
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }

            NavigationStack {
                SubscriptionsView()
            }
            .tabItem {
                Label("Subscriptions", systemImage: "play.rectangle.on.rectangle.fill")
            }

            NavigationStack {
                CreateView()
            }
            .tabItem {
                Label("Create", systemImage: "plus.circle.fill")
            }

            NavigationStack {
                LibraryView()
            }
            .tabItem {
                Label("You", systemImage: "person.crop.circle.fill")
            }
        }
        .tint(.red)
    }

    @ViewBuilder
    private var signedInFeed: some View {
        if viewModel.isLoading {
            ProgressView("Loading your YouTube subscriptions…")
                .padding(.top, 40)
        } else if let errorMessage = viewModel.errorMessage {
            ContentUnavailableView("Couldn’t load YouTube", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                .padding(.horizontal)
        } else if viewModel.videos.isEmpty {
            ContentUnavailableView("No videos yet", systemImage: "play.slash", description: Text("Your signed-in YouTube subscription activity will appear here."))
                .padding(.horizontal)
        } else {
            ForEach(viewModel.videos) { video in
                YouTubeVideoCard(video: video)
            }
        }
    }

    private var chipScroller: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(chips, id: \.self) { chip in
                    Text(chip)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(chip == "All" ? Color.primary : Color(.secondarySystemBackground))
                        .foregroundStyle(chip == "All" ? Color(.systemBackground) : Color.primary)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal)
        }
    }
}

struct ModernHeader: View {
    let isSignedIn: Bool
    let signInAction: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 7) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.red)
                        .frame(width: 34, height: 24)

                    Image(systemName: "play.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                }

                Text("Streamline")
                    .font(.title3.weight(.black))
                    .tracking(-0.7)
            }

            Spacer()

            HeaderButton(systemName: "airplayvideo")
            HeaderButton(systemName: "bell")
            HeaderButton(systemName: "magnifyingglass")
            Button(action: signInAction) {
                Text(isSignedIn ? "Live" : "Sign in")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isSignedIn ? Color.green.opacity(0.16) : Color.red.opacity(0.14), in: Capsule())
                    .foregroundStyle(isSignedIn ? .green : .red)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
}

struct SignInPrompt: View {
    let action: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(.red)

            Text("Sign in to YouTube")
                .font(.title3.weight(.bold))

            Text("Connect your Google account to load real videos from your YouTube subscription activity. The YouTube Data API does not provide the personalized Home feed, so this uses your signed-in activity feed instead.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Sign in with Google", action: action)
                .buttonStyle(.borderedProminent)
                .tint(.red)
        }
        .padding(22)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal)
    }
}

struct HeaderButton: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.headline)
            .frame(width: 34, height: 34)
            .background(Color(.secondarySystemBackground), in: Circle())
    }
}

struct VideoCard: View {
    let video: Video

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(video.gradient)
                    .frame(height: 218)
                    .overlay(alignment: .leading) {
                        VStack(alignment: .leading, spacing: 10) {
                            Image(systemName: video.icon)
                                .font(.system(size: 46, weight: .bold))
                            Text(video.topic)
                                .font(.title2.weight(.heavy))
                                .multilineTextAlignment(.leading)
                        }
                        .foregroundStyle(.white)
                        .padding(24)
                    }
                    .shadow(color: video.shadowColor.opacity(0.22), radius: 20, x: 0, y: 12)

                Text(video.duration)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(.black.opacity(0.78), in: Capsule())
                    .foregroundStyle(.white)
                    .padding(14)
            }
            .padding(.horizontal)

            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(video.avatarColor.gradient)
                    .frame(width: 44, height: 44)
                    .overlay {
                        Text(video.channelInitial)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 5) {
                    Text(video.title)
                        .font(.headline)
                        .lineLimit(2)

                    Text("\(video.channel) • \(video.views) views • \(video.age)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "ellipsis")
                    .font(.headline)
                    .rotationEffect(.degrees(90))
                    .padding(.top, 4)
            }
            .padding(.horizontal)
        }
    }
}

struct YouTubeVideoCard: View {
    let video: YouTubeVideo

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AsyncImage(url: video.thumbnailURL) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                ZStack {
                    LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: "play.fill")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(height: 218)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(.horizontal)

            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(.red.gradient)
                    .frame(width: 44, height: 44)
                    .overlay {
                        Text(String(video.channelTitle.prefix(1)))
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 5) {
                    Text(video.title)
                        .font(.headline)
                        .lineLimit(2)

                    Text("\(video.channelTitle) • \(video.relativeAge)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal)
        }
        .onTapGesture {
            if let watchURL = video.watchURL {
                UIApplication.shared.open(watchURL)
            }
        }
    }
}

@MainActor
final class YouTubeFeedViewModel: ObservableObject {
    @Published var videos: [YouTubeVideo] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let authService = YouTubeAuthService()
    private let apiClient = YouTubeAPIClient()

    var isSignedIn: Bool { authService.isSignedIn }

    func signInAndLoadFeed() async {
        guard YouTubeConfiguration.clientID != "YOUR_IOS_CLIENT_ID.apps.googleusercontent.com" else {
            errorMessage = "Add your Google iOS OAuth client ID in YouTubeConfiguration.swift before signing in."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let token = try await authService.signIn()
            videos = try await apiClient.fetchSubscriptionActivity(accessToken: token)
            objectWillChange.send()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

struct SubscriptionsView: View {
    var body: some View {
        PlaceholderPage(
            title: "Subscriptions",
            systemImage: "play.rectangle.on.rectangle.fill",
            message: "Fresh uploads from your favorite creators, arranged in a clean modern feed."
        )
    }
}

struct CreateView: View {
    var body: some View {
        PlaceholderPage(
            title: "Create",
            systemImage: "plus.circle.fill",
            message: "Upload, go live, or draft a post from one central creation hub."
        )
    }
}

struct LibraryView: View {
    var body: some View {
        PlaceholderPage(
            title: "You",
            systemImage: "person.crop.circle.fill",
            message: "History, playlists, downloads, and your channel live here."
        )
    }
}

struct PlaceholderPage: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: systemImage)
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(.red)

            Text(title)
                .font(.largeTitle.weight(.bold))

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .navigationTitle(title)
    }
}

struct Video: Identifiable {
    let id = UUID()
    let title: String
    let channel: String
    let views: String
    let age: String
    let duration: String
    let topic: String
    let icon: String
    let channelInitial: String
    let avatarColor: Color
    let gradient: LinearGradient
    let shadowColor: Color

    static let sampleVideos: [Video] = [
        Video(
            title: "Designing a next-generation mobile video feed",
            channel: "Pixel Lab",
            views: "1.2M",
            age: "2 days ago",
            duration: "12:48",
            topic: "Modern UI teardown",
            icon: "sparkles",
            channelInitial: "P",
            avatarColor: .purple,
            gradient: LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing),
            shadowColor: .red
        ),
        Video(
            title: "SwiftUI animations that make apps feel premium",
            channel: "Code Avenue",
            views: "486K",
            age: "1 week ago",
            duration: "18:05",
            topic: "SwiftUI motion kit",
            icon: "swift",
            channelInitial: "C",
            avatarColor: .blue,
            gradient: LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing),
            shadowColor: .blue
        ),
        Video(
            title: "Creator studio tour: filming, editing, and publishing faster",
            channel: "North Studio",
            views: "92K",
            age: "3 hours ago",
            duration: "09:31",
            topic: "Creator workflow",
            icon: "camera.fill",
            channelInitial: "N",
            avatarColor: .green,
            gradient: LinearGradient(colors: [.mint, .teal], startPoint: .topLeading, endPoint: .bottomTrailing),
            shadowColor: .teal
        )
    ]
}

#Preview {
    ContentView()
}
