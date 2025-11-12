# 🧭 Router

A powerful, type-safe navigation system for SwiftUI that eliminates navigation spaghetti code and makes your app's navigation flow predictable, testable, and maintainable.

## 📋 Table of Contents

- [Why Router?](#why-router)
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Core Components](#core-components)
- [Basic Usage](#basic-usage)
- [Advanced Features](#advanced-features)
- [Public Properties Examples](#public-properties-examples)
- [Testing](#testing)
- [FAQ](#faq)
- [License](#license)

---

## 🎯 Why Router?

Traditional SwiftUI navigation often leads to:

- Multiple `@State` variables per screen
- Navigation logic scattered across views
- Hard-to-test flows
- Not type-safe
- No navigation history tracking

**Router** centralizes navigation with:

- Centralized stack management  
- Type-safe route enums  
- Built-in sheet & fullScreenCover handling  
- Interceptor hooks for guards, analytics, etc.  

---

## ✨ Features

### Core Features
- ✅ Type-Safe Navigation (enum-based routes)
- ✅ Centralized Logic
- ✅ History Tracking
- ✅ Zero `@State` Variables
- ✅ Deep Linking Ready

### Advanced Features
- 🚀 Push Strategies: `.always`, `.ifNotExists`, `.navigateOrPush`
- 🎯 Interceptor for pre/post navigation/presentation hooks
- 🔄 Fully SwiftUI Native
- 🎨 Flexible & Testable

---

## 📦 Requirements

- iOS 16.0+
- Swift 5.9+
- Xcode 15.0+

---

## 🚀 Installation

### Swift Package Manager
```swift
dependencies: [
    .package(url: "https://github.com/konotori/Router.git", from: "1.0.0")
]
```

### Manual Installation

- Add source files:
  - `BaseRouter.swift`
  - `Interceptor.swift`
  - `GenericNavigationStack.swift`  

---

## ⚡ Quick Start

### Step 1: Define Routes
```swift
enum AppRoute: Hashable {
    case home
    case profile(userId: String)
    case settings
    case editProfile(userId: String)
}

enum AppSheet: String, Identifiable {
    var id: String {
        self.rawValue
    } 
    
    case userInfo(id: String)
    case createPost
}

enum AppCover: String, Identifiable {
    var id: String {
        self.rawValue
    } 
    
    case login
    case onboarding
}
```

### Step 2: Create Router
```swift
class AppRouter: BaseRouter<AppRoute, AppSheet, AppCover> {}
```

### Step 3: Integrate NavigationStack
```swift
struct ContentView: View {
    @StateObject private var router = AppRouter()
    
    var body: some View {
        NavigationStack(path: $router.path) {
            HomeView()
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .home: 
                        HomeView()
                    case .profile(let id): 
                        ProfileView(userId: id)
                    case .settings: 
                        SettingsView()
                    case .editProfile(let id): 
                        EditProfileView(userId: id)
                    }
                }
        }
        .sheet(item: $router.sheetBinding) { sheet in
            switch sheet {
            case .userInfo(let id): 
                UserInfoView(userId: id)
            case .createPost: 
                CreatePostView()
            }
        }
        .fullScreenCover(item: $router.fullScreenCoverBinding) { cover in
            switch cover {
            case .login: 
                LoginView()
            case .onboarding: 
                OnboardingView()
            }
        }
        .environmentObject(router)
    }
}
```

### Step 4: Navigate!
```swift
struct HomeView: View {
    @EnvironmentObject var router: AppRouter
    
    var body: some View {
        VStack(spacing: 20) {
            Button("View Profile") {
                router.push(.profile(userId: "123"))
            }
            
            Button("Settings") {
                router.push(.settings)
            }
            
            Button("Show User Info Sheet") {
                router.presentSheet(.userInfo(id: "456"))
            }
            
            Button("Back") {
                router.pop()
            }
            
            Button("Back to Home") {
                router.popToRoot()
            }
        }
        .navigationTitle("Home")
    }
}
```

**That's it! You're ready to go!** 🎉

---

## 🚦 Push Strategies
```swift
// Always push new route (creates duplicate if exists)
router.push(.profile(userId: "123"), strategy: .always)

// Push only if route doesn't exist in stack
router.push(.profile(userId: "123"), strategy: .ifNotExists)

// Navigate to existing route OR push if not in stack
router.push(.profile(userId: "123"), strategy: .navigateOrPush)
```

**When to use each strategy:**
- `.always` - Default behavior, good for general navigation
- `.ifNotExists` - Prevents duplicate screens in the stack
- `.navigateOrPush` - Perfect for deep linking, tab switching, or "go to X" features

---

## 🔥 Advanced Features

### 1. Deep Linking

Handle deep links by parsing URLs and building the navigation stack programmatically:
```swift
class AppRouter: BaseRouter<AppRoute, AppSheet, AppCover> {
    func handle(deepLink url: URL) {
        // Parse URL: myapp://profile/123/edit
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return
        }
        
        let pathComponents = components.path.split(separator: "/")
        
        // Clear current stack
        popToRoot()
        
        // Build navigation stack based on URL
        if pathComponents.first == "profile" {
            if let userId = pathComponents.dropFirst().first {
                push(.profile(userId: String(userId)))
                
                // Continue building stack for nested routes
                if pathComponents.contains("edit") {
                    push(.editProfile(userId: String(userId)))
                }
            }
        } else if pathComponents.first == "settings" {
            push(.settings)
        }
    }
}

// Usage in App or SceneDelegate
router.handle(deepLink: URL(string: "myapp://profile/123/edit")!)
```

### 2. Tab-Based Navigation

Each tab maintains its own independent navigation stack:
```swift
struct MainTabView: View {
    @StateObject private var homeRouter = BaseRouter<HomeRoute, HomeSheet, HomeCover>()
    @StateObject private var searchRouter = BaseRouter<SearchRoute, SearchSheet, SearchCover>()
    @StateObject private var profileRouter = BaseRouter<ProfileRoute, ProfileSheet, ProfileCover>()
    
    var body: some View {
        TabView {
            // Home Tab
            NavigationStack(path: $homeRouter.path) {
                HomeView()
                    .navigationDestination(for: HomeRoute.self) { route in
                        switch route {
                        case .feed: 
                            FeedView()
                        case .detail(let id): 
                            DetailView(id: id)
                        case .comments(let postId): 
                            CommentsView(postId: postId)
                        }
                    }
            }
            .environmentObject(homeRouter)
            .tabItem { Label("Home", systemImage: "house") }
            
            // Search Tab
            NavigationStack(path: $searchRouter.path) {
                SearchView()
                    .navigationDestination(for: SearchRoute.self) { route in
                        switch route {
                        case .results(let query): 
                            SearchResultsView(query: query)
                        case .filter: 
                            FilterView()
                        }
                    }
            }
            .environmentObject(searchRouter)
            .tabItem { Label("Search", systemImage: "magnifyingglass") }
            
            // Profile Tab
            NavigationStack(path: $profileRouter.path) {
                ProfileView()
                    .navigationDestination(for: ProfileRoute.self) { route in
                        switch route {
                        case .settings: 
                            SettingsView()
                        case .edit: 
                            EditProfileView()
                        case .posts: 
                            UserPostsView()
                        }
                    }
            }
            .environmentObject(profileRouter)
            .tabItem { Label("Profile", systemImage: "person") }
        }
    }
}
```

### 3. Interceptor System

Interceptor provides powerful hooks for intercepting and responding to navigation events. Perfect for authentication guards, analytics, logging, and more.

#### Authentication Interceptor

Block unauthorized users from accessing protected screens:
```swift
class AuthInterceptor: Interceptor<AppRoute, AppSheet, AppCover> {
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    
    func shouldProcess(
        _ event: NavigationEvent<AppRoute>, 
        for router: BaseRouter<AppRoute, AppSheet, AppCover>
    ) -> Bool {
        switch event {
        case .push(.profile), .push(.settings), .push(.editProfile):
            if !isLoggedIn {
                // Show login screen instead
                router.presentFullScreenCover(.login)
                return false  // Block navigation
            }
            return true
            
        default: 
            return true
        }
    }
    
    func didProcess(
        _ event: NavigationEvent<AppRoute>, 
        for router: BaseRouter<AppRoute, AppSheet, AppCover>
    ) {
        // Log successful navigation
        print("✅ Navigation allowed: \(event)")
    }
}

// Add to router
router.addInterceptor(AuthInterceptor())
```

#### Analytics Interceptor

Track screen views and user navigation patterns:
```swift
class AnalyticsInterceptor: Interceptor<AppRoute, AppSheet, AppCover> {
    private let analytics: AnalyticsService
    
    init(analytics: AnalyticsService) {
        self.analytics = analytics
    }
    
    func shouldProcess(
        _ event: NavigationEvent<AppRoute>, 
        for router: BaseRouter<AppRoute, AppSheet, AppCover>
    ) -> Bool {
        return true  // Never block, just observe
    }
    
    func didProcess(
        _ event: NavigationEvent<AppRoute>, 
        for router: BaseRouter<AppRoute, AppSheet, AppCover>
    ) {
        switch event {
        case .push(let route):
            analytics.trackScreenView(
                screen: "\(route)",
                properties: [
                    "navigation_depth": router.navigationDepth,
                    "previous_screen": router.routeHistory.dropLast().last?.description ?? "none"
                ]
            )
            
        case .pop:
            analytics.trackEvent("screen_dismissed", properties: [
                "from_screen": router.currentRouteName,
                "to_screen": router.path.last?.description ?? "root"
            ])
            
        case .presentSheet(let sheet):
            analytics.trackScreenView(screen: "sheet_\(sheet)", properties: ["type": "sheet"])
            
        case .presentFullScreenCover(let cover):
            analytics.trackScreenView(screen: "cover_\(cover)", properties: ["type": "fullscreen"])
            
        default:
            break
        }
    }
}

// Add to router
router.addInterceptor(AnalyticsInterceptor(analytics: AnalyticsService.shared))
```

#### Logging Interceptor

Debug navigation flows in development:
```swift
class LoggingInterceptor: Interceptor<AppRoute, AppSheet, AppCover> {
    func shouldProcess(
        _ event: NavigationEvent<AppRoute>, 
        for router: BaseRouter<AppRoute, AppSheet, AppCover>
    ) -> Bool {
        #if DEBUG
        print("🚀 Navigation Event: \(event)")
        print("   Current Stack: \(router.routesFromRoot)")
        print("   Depth: \(router.navigationDepth)")
        #endif
        return true
    }
    
    func didProcess(
        _ event: NavigationEvent<AppRoute>, 
        for router: BaseRouter<AppRoute, AppSheet, AppCover>
    ) {
        #if DEBUG
        print("✅ Navigation Completed")
        print("   New Stack: \(router.routesFromRoot)")
        print("   History Count: \(router.routeHistory.count)")
        print("---")
        #endif
    }
}

// Only add in debug builds
#if DEBUG
router.addInterceptor(LoggingInterceptor())
#endif
```

#### Feature Flag Interceptor

Control access to experimental features:
```swift
class FeatureFlagInterceptor: Interceptor<AppRoute, AppSheet, AppCover> {
    private let featureFlags: FeatureFlagService
    
    init(featureFlags: FeatureFlagService) {
        self.featureFlags = featureFlags
    }
    
    func shouldProcess(
        _ event: NavigationEvent<AppRoute>, 
        for router: BaseRouter<AppRoute, AppSheet, AppCover>
    ) -> Bool {
        switch event {
        case .push(.newExperimentalFeature):
            return featureFlags.isEnabled(.experimentalFeature)
            
        case .presentSheet(.betaFeatureSheet):
            guard featureFlags.isEnabled(.betaSheet) else {
                // Show alternative or info message
                router.presentSheet(.comingSoon)
                return false
            }
            return true
            
        default:
            return true
        }
    }
}

router.addInterceptor(FeatureFlagInterceptor(featureFlags: .shared))
```

#### Chaining Multiple Interceptor

Interceptor is processed in the order it's added:
```swift
// Setup router with multiple Interceptor
let router = AppRouter()

// 1. Check authentication first
router.addInterceptor(AuthInterceptor())

// 2. Then check feature flags
router.addInterceptor(FeatureFlagInterceptor(featureFlags: .shared))

// 3. Log everything (after guards)
#if DEBUG
router.addInterceptor(LoggingInterceptor())
#endif

// 4. Track analytics (always last)
router.addInterceptor(AnalyticsInterceptor(analytics: .shared))
```

---

## 🔑 Public Properties & Real-World Usage

### Navigation State Monitoring

Perfect for showing breadcrumbs, back buttons, or navigation-dependent UI:
```swift
struct NavigationToolbar: View {
    @EnvironmentObject var router: AppRouter
    
    var body: some View {
        HStack {
            // Show back button only when possible
            if router.canPop {
                Button(action: { router.pop() }) {
                    Label("Back", systemImage: "chevron.left")
                }
            }
            
            Spacer()
            
            // Breadcrumb navigation
            Text(router.currentRouteName)
                .font(.headline)
            
            Spacer()
            
            // Show depth indicator
            Text("Level \(router.navigationDepth)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}
```

### Debug Panel

Show navigation state for development and QA:
```swift
struct DebugNavigationPanel: View {
    @EnvironmentObject var router: AppRouter
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Text("🔍 Navigation Debug")
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
            }
            
            if isExpanded {
                Group {
                    Text("Current: \(router.currentRouteName)")
                    Text("Depth: \(router.navigationDepth)")
                    
                    Divider()
                    
                    Text("Stack (Root → Current):")
                        .font(.caption.bold())
                    ForEach(router.routesFromRoot.indices, id: \.self) { index in
                        Text("  \(index): \(router.routesFromRoot[index])")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    Text("History (All \(router.routeHistory.count) routes):")
                        .font(.caption.bold())
                    ForEach(router.routeHistory.suffix(5).reversed(), id: \.self) { route in
                        Text("  • \(route)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.leading)
            }
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .foregroundColor(.white)
        .cornerRadius(10)
    }
}

// Usage: Overlay on your app
#if DEBUG
.overlay(
    DebugNavigationPanel()
        .padding(),
    alignment: .bottom
)
#endif
```

### Analytics Integration

Track user journey through your app:
```swift
class NavigationAnalytics: ObservableObject {
    @Published private(set) var sessionRoutes: [String] = []
    
    func trackNavigation(from router: AppRouter) {
        // Track current screen
        if let current = router.currentRoute {
            sessionRoutes.append("\(current)")
        }
        
        // Send to analytics service
        AnalyticsService.shared.logEvent("navigation", parameters: [
            "screen": router.currentRouteName,
            "depth": router.navigationDepth,
            "session_screens": sessionRoutes.count,
            "can_go_back": router.canPop
        ])
    }
    
    func getNavigationSummary(from router: AppRouter) -> String {
        """
        Session Summary:
        - Total Screens: \(sessionRoutes.count)
        - Current: \(router.currentRouteName)
        - Max Depth: \(router.navigationDepth)
        - Unique Routes: \(Set(sessionRoutes).count)
        """
    }
}
```

### Smart Back Navigation

Implement "Back to Previous Section" buttons:
```swift
struct SmartBackButton: View {
    @EnvironmentObject var router: AppRouter
    let targetRoute: AppRoute
    
    var body: some View {
        Button(action: navigateBack) {
            Label("Back to \(targetRoute)", systemImage: "arrow.left")
        }
        .disabled(!canNavigateBack)
    }
    
    private var canNavigateBack: Bool {
        router.routesFromRoot.contains(targetRoute)
    }
    
    private func navigateBack() {
        // Pop until we reach target route
        while router.currentRoute != targetRoute && router.canPop {
            router.pop()
        }
    }
}

// Usage
SmartBackButton(targetRoute: .home)
```

### Navigation History Viewer

Show user their navigation history:
```swift
struct NavigationHistoryView: View {
    @EnvironmentObject var router: AppRouter
    
    var body: some View {
        List {
            Section("Current Path") {
                ForEach(router.routesFromRoot.indices, id: \.self) { index in
                    HStack {
                        Image(systemName: "\(index + 1).circle.fill")
                        Text("\(router.routesFromRoot[index])")
                        
                        if index == router.routesFromRoot.count - 1 {
                            Spacer()
                            Text("Current")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            
            Section("Recent History (\(router.routeHistory.count) total)") {
                ForEach(router.routeHistory.suffix(10).reversed(), id: \.self) { route in
                    HStack {
                        Image(systemName: "clock")
                        Text("\(route)")
                    }
                }
            }
            
            Section("Quick Actions") {
                Button("Jump to Root") {
                    router.popToRoot()
                }
                .disabled(router.navigationDepth <= 1)
                
                Button("Go Back") {
                    router.pop()
                }
                .disabled(!router.canPop)
            }
        }
        .navigationTitle("Navigation History")
    }
}
```

### Properties Quick Reference

| Property | Type | Description | Use Case |
|----------|------|-------------|----------|
| `currentRoute` | `Route?` | Currently displayed route | Conditional UI based on screen |
| `currentRouteName` | `String` | Route name as string | Analytics, logging, breadcrumbs |
| `navigationDepth` | `Int` | Stack depth (0 = root) | UI indicators, limits |
| `canPop` | `Bool` | Whether back is possible | Enable/disable back buttons |
| `routeHistory` | `[Route]` | All visited routes | Analytics, debugging |
| `routesFromRoot` | `[Route]` | Current path from root | Breadcrumbs, progress |
| `routesToRoot` | `[Route]` | Path to root (reversed) | "Jump to" menus |

---

## 🧪 Testing

### Basic Navigation Tests
```swift
import XCTest
@testable import YourApp

class RouterTests: XCTestCase {
    var router: BaseRouter<AppRoute, AppSheet, AppCover>!
    
    override func setUp() {
        super.setUp()
        router = BaseRouter<AppRoute, AppSheet, AppCover>()
    }
    
    override func tearDown() {
        router = nil
        super.tearDown()
    }
    
    func testPushRoute() {
        // Given
        XCTAssertNil(router.currentRoute)
        
        // When
        router.push(.home)
        
        // Then
        XCTAssertEqual(router.currentRoute, .home)
        XCTAssertEqual(router.navigationDepth, 1)
    }
    
    func testPopRoute() {
        // Given
        router.push(.home)
        router.push(.profile(userId: "123"))
        XCTAssertEqual(router.navigationDepth, 2)
        
        // When
        router.pop()
        
        // Then
        XCTAssertEqual(router.currentRoute, .home)
        XCTAssertEqual(router.navigationDepth, 1)
    }
    
    func testPopToRoot() {
        // Given
        router.push(.home)
        router.push(.profile(userId: "123"))
        router.push(.settings)
        
        // When
        router.popToRoot()
        
        // Then
        XCTAssertEqual(router.navigationDepth, 0)
        XCTAssertTrue(router.path.isEmpty)
    }
    
    func testNavigationDepth() {
        // Given & When
        router.push(.home)
        router.push(.profile(userId: "123"))
        router.push(.editProfile(userId: "123"))
        
        // Then
        XCTAssertEqual(router.navigationDepth, 3)
        XCTAssertEqual(router.routesFromRoot.count, 3)
    }
    
    func testRouteHistory() {
        // Given & When
        router.push(.home)
        router.push(.profile(userId: "123"))
        router.pop()
        router.push(.settings)
        
        // Then
        XCTAssertEqual(router.routeHistory.count, 4)
        XCTAssertEqual(router.routeHistory.last, .settings)
    }
}
```

### Push Strategy Tests
```swift
func testPushStrategyAlways() {
    // Given
    router.push(.profile(userId: "123"))
    
    // When
    router.push(.profile(userId: "123"), strategy: .always)
    
    // Then
    XCTAssertEqual(router.navigationDepth, 2)
    XCTAssertEqual(router.path.count, 2)
}

func testPushStrategyIfNotExists() {
    // Given
    router.push(.profile(userId: "123"))
    let depthBefore = router.navigationDepth
    
    // When
    router.push(.profile(userId: "123"), strategy: .ifNotExists)
    
    // Then - Should not add duplicate
    XCTAssertEqual(router.navigationDepth, depthBefore)
}

func testPushStrategyNavigateOrPush() {
    // Given
    router.push(.home)
    router.push(.profile(userId: "123"))
    router.push(.settings)
    
    // When - Navigate to existing route
    router.push(.home, strategy: .navigateOrPush)
    
    // Then - Should pop back to home
    XCTAssertEqual(router.currentRoute, .home)
    XCTAssertEqual(router.navigationDepth, 1)
}
```

### Interceptor Tests
```swift
class MockAuthInterceptor: Interceptor<AppRoute, AppSheet, AppCover> {
    var shouldAllow = true
    var processedEvents: [NavigationEvent<AppRoute>] = []
    
    func shouldProcess(
        _ event: NavigationEvent<AppRoute>,
        for router: BaseRouter<AppRoute, AppSheet, AppCover>
    ) -> Bool {
        processedEvents.append(event)
        return shouldAllow
    }
}

func testInterceptorBlocksNavigation() {
    // Given
    let Interceptor = MockAuthInterceptor()
    Interceptor.shouldAllow = false
    router.addInterceptor(Interceptor)
    
    // When
    router.push(.profile(userId: "123"))
    
    // Then
    XCTAssertNil(router.currentRoute)
    XCTAssertEqual(Interceptor.processedEvents.count, 1)
}

func testInterceptorAllowsNavigation() {
    // Given
    let Interceptor = MockAuthInterceptor()
    Interceptor.shouldAllow = true
    router.addInterceptor(Interceptor)
    
    // When
    router.push(.home)
    
    // Then
    XCTAssertEqual(router.currentRoute, .home)
    XCTAssertEqual(Interceptor.processedEvents.count, 1)
}
```

### Deep Link Tests
```swift
func testDeepLinkHandling() {
    // Given
    let deepLink = URL(string: "myapp://profile/123/edit")!
    
    // When
    router.handle(deepLink: deepLink)
    
    // Then
    XCTAssertEqual(router.navigationDepth, 2)
    XCTAssertEqual(router.path[0], .profile(userId: "123"))
    XCTAssertEqual(router.path[1], .editProfile(userId: "123"))
}
```

---

## ❓ FAQ

**Q: Can I have multiple routers?**  
A: Yes! Use one router per navigation stack. This is especially useful for tab-based apps where each tab has its own independent navigation.

**Q: How to handle modal presentations?**  
A: Use `.sheet()` or `.fullScreenCover()` with `router.sheetBinding` or `router.fullScreenCoverBinding`. Present modals with `router.presentSheet(.userInfo)` or `router.presentFullScreenCover(.login)`.

**Q: How do I handle navigation guards?**  
A: Use Interceptor! Create a Interceptor class that returns `false` in `shouldProcess()` to block navigation. Perfect for authentication checks.

**Q: How do I inject the router into child views?**  
A: Use `.environmentObject(router)` at the root NavigationStack and `@EnvironmentObject var router: AppRouter` in child views.

**Q: Can I customize the navigation animation?**  
A: Yes, SwiftUI's NavigationStack handles animations automatically, but you can customize transitions using `.transition()` modifiers on your destination views.

**Q: How do I handle navigation after async operations?**  
A: Navigation calls are synchronous, but you can trigger them after async work:
```swift
Task {
    await viewModel.saveData()
    await MainActor.run {
        router.push(.success)
    }
}
```

**Q: Can I navigate from outside a view (like from a view model)?**  
A: Yes! Pass the router to your view model:
```swift
class ProfileViewModel: ObservableObject {
    let router: AppRouter
    
    func logout() {
        // Perform logout...
        router.popToRoot()
        router.presentFullScreenCover(.login)
    }
}
```

**Q: How do I prevent users from going back to certain screens?**  
A: Use Interceptor to intercept pop events, or restructure your navigation flow to use `.presentFullScreenCover()` for login/onboarding screens that shouldn't allow back navigation.

---

## 📄 Acknowledgements
This router library is inspired by and **refactored from** the original [NavigationRouter](https://github.com/duongcuong4395/MyPackage/blob/main/Sources/NavigationRouter) project by Duong Cuong.  

We’ve enhanced it with:  
- **Interceptor system**: allows adding analytics, logging, or navigation guards without needing to subclass the router.  
- **Global sheet & fullScreenCover support**: useful for handling deep links or app-wide modal flows.  

Thanks to the original author for providing the foundation.

## 📄 License

MIT License
