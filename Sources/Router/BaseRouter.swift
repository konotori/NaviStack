//
//  BaseRouter.swift
//
//
//  Created by Amitayus on 12/11/25.
//

import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.router", category: "navigation")

/// A type-safe navigation router for SwiftUI.
///
/// **The golden rule:** every navigation must go through the router.
/// Do **not** push views with `NavigationLink(value:)` — that grows
/// `NavigationPath` behind the router's back and desynchronizes
/// `currentRoute` / `navigationDepth` / `popTo`. Use
/// `Button { router.push(.route) }` instead.
///
/// System-driven removals (back swipe, navigation bar back button) are
/// observed and reported to interceptors as `NavigationEvent.systemPop`.
@MainActor
open class BaseRouter<NavRoute: Hashable, SheetRoute: Identifiable, CoverRoute: Identifiable>: ObservableObject {
	// MARK: - States

	@Published public var path = NavigationPath() {
		didSet {
			guard !isPerformingProgrammaticNavigation else {
				return
			}
			handleExternalPathChange()
		}
	}
	@Published private var globalSheet: SheetRoute?
	@Published private var globalFullScreenCover: CoverRoute?
	private var routeStack: [NavRoute] = []
	private var interceptors: [(token: InterceptorToken, interceptor: any Interceptor<NavRoute, SheetRoute, CoverRoute>)] = []

	/// True while the router itself mutates `path`, so `didSet` can tell
	/// router-driven changes apart from system-driven ones (back swipe).
	private var isPerformingProgrammaticNavigation = false

	public var sheetBinding: Binding<SheetRoute?> {
		Binding(
			get: { self.globalSheet },
			set: { [weak self] newValue in
				guard let self else {
					return
				}

				if newValue == nil, self.globalSheet != nil {
					// Interactive dismiss (drag gesture) — the sheet is already
					// gone on screen, so this cannot be blocked. Sync state and
					// notify interceptors via didProcess only.
					// To prevent the gesture itself, use `.interactiveDismissDisabled()`.
					self.globalSheet = nil
					self.didProcessSheet(.dismiss(programmatic: false))
				}
			}
		)
	}

	public var fullScreenCoverBinding: Binding<CoverRoute?> {
		Binding(
			get: { self.globalFullScreenCover },
			set: { [weak self] newValue in
				guard let self else {
					return
				}

				if newValue == nil, self.globalFullScreenCover != nil {
					// Interactive dismiss — already complete, cannot be blocked.
					self.globalFullScreenCover = nil
					self.didProcessCover(.dismiss(programmatic: false))
				}
			}
		)
	}

	// MARK: - Init

	public init() {}

	// MARK: - Public Properties

	public var currentRoute: NavRoute? {
		routeStack.last
	}

	public var currentRouteName: String {
		currentRoute.map { String(describing: $0) } ?? "Root"
	}

	public var navigationDepth: Int {
		routeStack.count
	}

	public var canPop: Bool {
		!routeStack.isEmpty && !path.isEmpty
	}

	public var presentedSheet: SheetRoute? {
		globalSheet
	}

	public var presentedFullScreenCover: CoverRoute? {
		globalFullScreenCover
	}

	/// Get routes from current position to root
	public var routesToRoot: [NavRoute] {
		Array(routeStack.reversed())
	}

	/// Get routes from root to current position
	public var routesFromRoot: [NavRoute] {
		routeStack
	}

	// MARK: - Public Navigation Methods

	public func push(_ route: NavRoute, strategy: PushStrategy = .always) {
		processNavigationInterceptor(event: .push(route, strategy: strategy)) {
			switch strategy {
			case .always:
				appendRoute(route)

			case .ifNotExists:
				if !containsRoute(route) {
					appendRoute(route)
				}

			case .navigateOrPush:
				// Nearest occurrence: jump back to the most recent matching route.
				if let existingIndex = routeStack.lastIndex(of: route) {
					navigateToExisting(at: existingIndex)
				} else {
					appendRoute(route)
				}
			}
		}
	}

	public func pop() {
		guard canPop else {
			logger.debug("pop() ignored - empty stack")
			return
		}

		processNavigationInterceptor(event: .pop) {
			performProgrammatic {
				path.removeLast()
				routeStack.removeLast()
			}
		}
	}

	/// Pops back to the **nearest** (most recent) occurrence of `route`.
	public func popTo(_ route: NavRoute) {
		guard let index = routeStack.lastIndex(of: route) else {
			logger.debug("popTo() ignored - route not found: \(String(describing: route))")
			return
		}

		processNavigationInterceptor(event: .popTo(route)) {
			navigateToExisting(at: index)
		}
	}

	public func popToRoot() {
		guard canPop else {
			return
		}

		processNavigationInterceptor(event: .popToRoot) {
			performProgrammatic {
				path.removeLast(path.count)
				routeStack.removeAll()
			}
		}
	}

	public func replace(with route: NavRoute) {
		processNavigationInterceptor(event: .replace(route)) {
			performProgrammatic {
				if !routeStack.isEmpty, !path.isEmpty {
					path.removeLast()
					routeStack.removeLast()
				}
				path.append(route)
				routeStack.append(route)
			}
		}
	}

	/// Replaces the whole navigation stack atomically in a single `path`
	/// mutation. This is the right tool for deep links and state
	/// restoration: interceptors see one `.setStack` event instead of a
	/// popToRoot + N pushes, and SwiftUI animates a single transition.
	public func setStack(_ routes: [NavRoute]) {
		processNavigationInterceptor(event: .setStack(routes)) {
			performProgrammatic {
				var newPath = NavigationPath()
				for route in routes {
					newPath.append(route)
				}
				path = newPath
				routeStack = routes
			}
		}
	}

	public func presentSheet(_ route: SheetRoute) {
		processSheetInterceptor(event: .present(route)) {
			globalSheet = route
		}
	}

	public func dismissSheet() {
		guard globalSheet != nil else {
			return
		}

		processSheetInterceptor(event: .dismiss(programmatic: true)) {
			globalSheet = nil
		}
	}

	public func presentFullScreenCover(_ route: CoverRoute) {
		processCoverInterceptor(event: .present(route)) {
			globalFullScreenCover = route
		}
	}

	public func dismissFullScreenCover() {
		guard globalFullScreenCover != nil else {
			return
		}

		processCoverInterceptor(event: .dismiss(programmatic: true)) {
			globalFullScreenCover = nil
		}
	}

	/// Dismisses any presented cover and sheet, then pops to root.
	/// Call this before handling a deep link so the destination is
	/// actually visible to the user.
	public func dismissAll() {
		dismissFullScreenCover()
		dismissSheet()
		popToRoot()
	}

	// MARK: - Public Query Methods

	public func isCurrentRoute(_ route: NavRoute) -> Bool {
		currentRoute == route
	}

	public func containsRoute(_ route: NavRoute) -> Bool {
		routeStack.contains(route)
	}

	// MARK: - Public Interceptor Management Methods

	@discardableResult
	public func addInterceptor<M: Interceptor>(_ interceptor: M) -> InterceptorToken
	where M.NavRoute == NavRoute,
		  M.SheetRoute == SheetRoute,
		  M.CoverRoute == CoverRoute
	{
		let token = InterceptorToken()
		interceptors.append((token, interceptor))
		return token
	}

	public func removeInterceptor(_ token: InterceptorToken) {
		interceptors.removeAll { $0.token == token }
	}

	public func clearInterceptors() {
		interceptors.removeAll()
	}

	// MARK: - Private Navigation Methods

	private func appendRoute(_ route: NavRoute) {
		performProgrammatic {
			path.append(route)
			routeStack.append(route)
		}
	}

	private func navigateToExisting(at index: Int) {
		guard index < routeStack.count - 1 else {
			return
		}

		let routesToPop = routeStack.count - index - 1
		performProgrammatic {
			path.removeLast(routesToPop)
			routeStack.removeLast(routesToPop)
		}
	}

	/// Runs a router-driven `path` mutation with the system-change observer
	/// suspended. `defer` guarantees the flag resets even if `body` throws.
	private func performProgrammatic(_ body: () -> Void) {
		isPerformingProgrammaticNavigation = true
		defer {
			isPerformingProgrammaticNavigation = false
		}
		body()
	}

	// MARK: - System Path Change Handling

	/// Called when `path` changes without the router's involvement:
	/// back swipe, navigation bar back button, or long-press back menu.
	private func handleExternalPathChange() {
		let pathCount = path.count
		let stackCount = routeStack.count

		if pathCount < stackCount {
			let difference = stackCount - pathCount
			let poppedRoutes = Array(routeStack.suffix(difference))
			routeStack.removeLast(difference)
			// The transition already happened — report it (didProcess only).
			didProcessNavigation(.systemPop(poppedRoutes))
		} else if pathCount > stackCount {
			// Someone pushed onto `path` without going through the router —
			// almost always a `NavigationLink(value:)`. The router can no
			// longer know what the current route is.
			logger.fault("""
			NavigationPath grew outside the router (path: \(pathCount), tracked: \(stackCount)). \
			Did you use NavigationLink(value:)? All navigation must go through the router \
			(router.push(...)), otherwise currentRoute/popTo will be wrong.
			""")
		}
	}

	// MARK: - Private Navigation Interceptor Helpers

	private func processNavigationInterceptor(event: NavigationEvent<NavRoute>, handler: () -> Void) {
		guard shouldProcessNavigation(event) else {
			return
		}

		handler()
		didProcessNavigation(event)
	}

	private func shouldProcessNavigation(_ event: NavigationEvent<NavRoute>) -> Bool {
		for (_, interceptor) in interceptors {
			guard interceptor.shouldProcess(event, for: self) else {
				logger.debug("Navigation blocked by \(String(describing: type(of: interceptor)))")
				return false
			}
		}
		return true
	}

	private func didProcessNavigation(_ event: NavigationEvent<NavRoute>) {
		for (_, interceptor) in interceptors {
			interceptor.didProcess(event, for: self)
		}
	}

	// MARK: - Private Sheet Interceptor Helpers

	private func processSheetInterceptor(event: SheetEvent<SheetRoute>, handler: () -> Void) {
		guard shouldProcessSheet(event) else {
			return
		}

		handler()
		didProcessSheet(event)
	}

	private func shouldProcessSheet(_ event: SheetEvent<SheetRoute>) -> Bool {
		for (_, interceptor) in interceptors {
			guard interceptor.shouldProcess(event, for: self) else {
				logger.debug("Sheet presentation blocked by \(String(describing: type(of: interceptor)))")
				return false
			}
		}
		return true
	}

	private func didProcessSheet(_ event: SheetEvent<SheetRoute>) {
		for (_, interceptor) in interceptors {
			interceptor.didProcess(event, for: self)
		}
	}

	// MARK: - Private Cover Interceptor Helpers

	private func processCoverInterceptor(event: CoverEvent<CoverRoute>, handler: () -> Void) {
		guard shouldProcessCover(event) else {
			return
		}

		handler()
		didProcessCover(event)
	}

	private func shouldProcessCover(_ event: CoverEvent<CoverRoute>) -> Bool {
		for (_, interceptor) in interceptors {
			guard interceptor.shouldProcess(event, for: self) else {
				logger.debug("Cover presentation blocked by \(String(describing: type(of: interceptor)))")
				return false
			}
		}
		return true
	}

	private func didProcessCover(_ event: CoverEvent<CoverRoute>) {
		for (_, interceptor) in interceptors {
			interceptor.didProcess(event, for: self)
		}
	}
}

// MARK: - State Restoration

public extension BaseRouter where NavRoute: Codable {
	/// Encodes the current navigation stack for persistence
	/// (e.g. `@SceneStorage`, `UserDefaults`).
	func encodedStack() throws -> Data {
		try JSONEncoder().encode(routesFromRoot)
	}

	/// Restores a previously encoded stack via ``setStack(_:)``.
	///
	/// Restoration goes through the interceptor chain like any other
	/// `.setStack` — an auth guard can legitimately block restoring into a
	/// protected screen when the user is no longer signed in.
	func restoreStack(from data: Data) throws {
		let routes = try JSONDecoder().decode([NavRoute].self, from: data)
		setStack(routes)
	}
}
