import Testing
import SwiftUI
import Foundation

@testable import Router

// MARK: - Test Helpers

private enum TestNavRoute: Hashable, Codable {
	case home
	case details
	case settings
}

private enum TestSheetRoute: String, Identifiable {
	var id: String {
		self.rawValue
	}

	case login
}

private enum TestCoverRoute: String, Identifiable {
	var id: String {
		self.rawValue
	}

	case login
}

private typealias TestRouter = BaseRouter<TestNavRoute, TestSheetRoute, TestCoverRoute>

private final class TestInterceptor: Interceptor {
	typealias NavRoute = TestNavRoute
	typealias SheetRoute = TestSheetRoute
	typealias CoverRoute = TestCoverRoute

	var shouldAllowNavigation = true
	var shouldAllowSheet = true
	var shouldAllowCover = true

	private(set) var navigationEvents: [NavigationEvent<TestNavRoute>] = []
	private(set) var sheetEvents: [SheetEvent<TestSheetRoute>] = []
	private(set) var coverEvents: [CoverEvent<TestCoverRoute>] = []
	/// navigationDepth observed at each didProcess call — analytics reads
	/// router state there, so it must already reflect the post-event state.
	private(set) var depthsAtDidProcess: [Int] = []

	func shouldProcess(_ event: NavigationEvent<TestNavRoute>, for router: TestRouter) -> Bool {
		shouldAllowNavigation
	}

	func didProcess(_ event: NavigationEvent<TestNavRoute>, for router: TestRouter) {
		navigationEvents.append(event)
		depthsAtDidProcess.append(router.navigationDepth)
	}

	func shouldProcess(_ event: SheetEvent<TestSheetRoute>, for router: TestRouter) -> Bool {
		shouldAllowSheet
	}

	func didProcess(_ event: SheetEvent<TestSheetRoute>, for router: TestRouter) {
		sheetEvents.append(event)
	}

	func shouldProcess(_ event: CoverEvent<TestCoverRoute>, for router: TestRouter) -> Bool {
		shouldAllowCover
	}

	func didProcess(_ event: CoverEvent<TestCoverRoute>, for router: TestRouter) {
		coverEvents.append(event)
	}
}

// MARK: - BaseRouter Tests

@MainActor
struct BaseRouterTests {

	// MARK: - Base State

	@Test
	func router_initialState() {
		let router = TestRouter()

		#expect(router.navigationDepth == 0)
		#expect(router.currentRoute == nil)
		#expect(router.currentRouteName == "Root")
		#expect(router.canPop == false)
		#expect(router.routesFromRoot.isEmpty)
		#expect(router.routesToRoot.isEmpty)
		#expect(router.path.count == 0)
		#expect(router.presentedSheet == nil)
		#expect(router.presentedFullScreenCover == nil)
	}

	@Test
	func router_routesFromRoot_returnsCurrentStack() {
		let router = TestRouter()
		#expect(router.routesFromRoot.isEmpty)

		router.push(.home)
		router.push(.details)
		#expect(router.routesFromRoot == [.home, .details])

		router.pop()
		#expect(router.routesFromRoot == [.home])
	}

	@Test
	func router_currentRouteName() {
		let router = BaseRouter<TestNavRoute, Never, Never>()

		router.push(.home)

		#expect(router.currentRouteName == "home")
	}

	// MARK: - Push & Pop

	@Test
	func router_pushAlways_appendsRoute() {
		let router = TestRouter()

		router.push(.home)
		router.push(.details)

		#expect(router.navigationDepth == 2)
		#expect(router.currentRoute == .details)
		#expect(router.canPop)
		#expect(router.path.count == 2)
	}

	@Test
	func router_pushIfNotExists_doesNotDuplicate() {
		let router = TestRouter()

		router.push(.home)
		router.push(.home, strategy: .ifNotExists)

		#expect(router.navigationDepth == 1)
		#expect(router.path.count == 1)
		#expect(router.currentRoute == .home)
	}

	@Test
	func router_pushIfNotExists_appendsWhenRouteNotInStack() {
		let router = TestRouter()

		router.push(.home)
		router.push(.details, strategy: .ifNotExists)

		#expect(router.navigationDepth == 2)
		#expect(router.currentRoute == .details)
		#expect(router.routesFromRoot == [.home, .details])
	}

	@Test
	func router_pushNavigateOrPush_navigateToExisting() {
		let router = TestRouter()

		router.push(.home)
		router.push(.details)
		router.push(.settings)

		// Navigate back to .details instead of pushing a duplicate
		router.push(.details, strategy: .navigateOrPush)

		#expect(router.navigationDepth == 2)
		#expect(router.currentRoute == .details)
		#expect(router.path.count == 2)
	}

	@Test
	func router_pushNavigateOrPush_pushesWhenRouteNotInStack() {
		let router = TestRouter()

		router.push(.home)
		router.push(.settings, strategy: .navigateOrPush)

		#expect(router.navigationDepth == 2)
		#expect(router.currentRoute == .settings)
		#expect(router.routesFromRoot == [.home, .settings])
	}

	@Test
	func router_pushNavigateOrPush_withDuplicates_jumpsToNearestOccurrence() {
		let router = TestRouter()

		// Stack: [home, details, home, settings] — .home appears twice
		router.push(.home)
		router.push(.details)
		router.push(.home)
		router.push(.settings)

		router.push(.home, strategy: .navigateOrPush)

		// Must land on the NEAREST .home (index 2), not the root one (index 0)
		#expect(router.routesFromRoot == [.home, .details, .home])
		#expect(router.navigationDepth == 3)
		#expect(router.path.count == 3)
	}

	@Test
	func router_pop_removesTopRoute() {
		let router = TestRouter()

		router.push(.home)
		router.push(.details)
		router.pop()

		#expect(router.navigationDepth == 1)
		#expect(router.currentRoute == .home)
		#expect(router.path.count == 1)
	}

	@Test
	func router_pop_onEmptyDoesNothing() {
		let router = TestRouter()

		router.pop()

		#expect(router.navigationDepth == 0)
		#expect(router.path.count == 0)
	}

	@Test
	func router_popTo_existingRoute() {
		let router = TestRouter()

		router.push(.home)
		router.push(.details)
		router.push(.settings)

		router.popTo(.home)

		#expect(router.navigationDepth == 1)
		#expect(router.currentRoute == .home)
		#expect(router.path.count == 1)
	}

	@Test
	func router_popTo_withDuplicates_popsToNearestOccurrence() {
		let router = TestRouter()

		// Stack: [details, home, details, settings] — .details appears twice
		router.push(.details)
		router.push(.home)
		router.push(.details)
		router.push(.settings)

		router.popTo(.details)

		// Must pop to the NEAREST .details (index 2), not the first one
		#expect(router.routesFromRoot == [.details, .home, .details])
		#expect(router.path.count == 3)
	}

	@Test
	func router_popTo_nonExistingRouteDoesNothing() {
		let router = TestRouter()

		router.push(.home)
		router.push(.details)

		router.popTo(.settings) // not in stack

		#expect(router.navigationDepth == 2)
		#expect(router.currentRoute == .details)
		#expect(router.path.count == 2)
	}

	@Test
	func router_popTo_currentRoute_doesNothing() {
		let router = TestRouter()

		router.push(.home)
		router.push(.details)
		router.push(.settings)

		router.popTo(.settings)

		#expect(router.navigationDepth == 3)
		#expect(router.currentRoute == .settings)
		#expect(router.routesFromRoot == [.home, .details, .settings])
	}

	@Test
	func router_popToRoot_clearsAll() {
		let router = TestRouter()

		router.push(.home)
		router.push(.details)

		router.popToRoot()

		#expect(router.navigationDepth == 0)
		#expect(router.currentRoute == nil)
		#expect(router.path.count == 0)
	}

	@Test
	func router_popToRoot_onEmptyStackDoesNothing() {
		let router = TestRouter()

		router.popToRoot()

		#expect(router.navigationDepth == 0)
		#expect(router.currentRoute == nil)
		#expect(router.path.count == 0)
	}

	// MARK: - Replace

	@Test
	func router_replace_onNonEmptyStackReplacesTop() {
		let router = TestRouter()

		router.push(.home)
		router.replace(with: .details)

		#expect(router.navigationDepth == 1)
		#expect(router.currentRoute == .details)
		#expect(router.path.count == 1)
	}

	@Test
	func router_replace_onEmptyStackJustPushes() {
		let router = TestRouter()

		router.replace(with: .home)

		#expect(router.navigationDepth == 1)
		#expect(router.currentRoute == .home)
		#expect(router.path.count == 1)
	}

	// MARK: - Set Stack

	@Test
	func router_setStack_replacesWholeStackAtomically() {
		let router = TestRouter()
		let interceptor = TestInterceptor()
		router.addInterceptor(interceptor)

		router.push(.settings)
		router.setStack([.home, .details])

		#expect(router.routesFromRoot == [.home, .details])
		#expect(router.path.count == 2)
		#expect(router.currentRoute == .details)
		// One .push event + one .setStack event — NOT popToRoot + N pushes
		#expect(interceptor.navigationEvents == [
			.push(.settings, strategy: .always),
			.setStack([.home, .details])
		])
	}

	@Test
	func router_setStack_empty_clearsStack() {
		let router = TestRouter()

		router.push(.home)
		router.setStack([])

		#expect(router.navigationDepth == 0)
		#expect(router.path.count == 0)
	}

	@Test
	func router_setStack_blockedByInterceptor_leavesStateUntouched() {
		let router = TestRouter()
		let interceptor = TestInterceptor()
		router.addInterceptor(interceptor)

		router.push(.home)
		interceptor.shouldAllowNavigation = false

		router.setStack([.details, .settings])

		#expect(router.routesFromRoot == [.home])
		#expect(router.path.count == 1)
	}

	// MARK: - Query API

	@Test
	func router_queryHelpers_workAsExpected() {
		let router = TestRouter()

		router.push(.home)
		router.push(.details)

		#expect(router.isCurrentRoute(.details))
		#expect(router.containsRoute(.home))
		#expect(router.routesFromRoot == [.home, .details])
		#expect(router.routesToRoot == [.details, .home])
	}

	// MARK: - System Pop (back swipe / back button)

	@Test
	func router_systemPop_keepsRouteStackInSync() {
		let router = TestRouter()

		router.push(.home)
		router.push(.details)
		router.push(.settings)

		// Simulate system back (swipe gesture / back button): SwiftUI
		// mutates `path` directly, without going through the router.
		router.path.removeLast()

		#expect(router.path.count == 2)
		#expect(router.navigationDepth == 2)
		#expect(router.currentRoute == .details)
	}

	@Test
	func router_systemPop_notifiesInterceptorWithPoppedRoutes() {
		let router = TestRouter()
		let interceptor = TestInterceptor()
		router.addInterceptor(interceptor)

		router.push(.home)
		router.push(.details)
		router.push(.settings)

		router.path.removeLast()

		#expect(interceptor.navigationEvents.last == .systemPop([.settings]))
		// State must already be synced when didProcess runs (analytics reads it there)
		#expect(interceptor.depthsAtDidProcess.last == 2)
	}

	@Test
	func router_systemPop_multipleRoutes_reportsAllInOrder() {
		let router = TestRouter()
		let interceptor = TestInterceptor()
		router.addInterceptor(interceptor)

		router.push(.home)
		router.push(.details)
		router.push(.settings)

		// Long-press back menu can pop several screens at once
		router.path.removeLast(2)

		#expect(interceptor.navigationEvents.last == .systemPop([.details, .settings]))
		#expect(router.navigationDepth == 1)
	}

	@Test
	func router_systemPop_cannotBeBlockedByInterceptor() {
		let router = TestRouter()
		let interceptor = TestInterceptor()
		interceptor.shouldAllowNavigation = false // blocks everything blockable
		router.addInterceptor(interceptor)
		router.clearInterceptors()

		// Build stack without the blocking interceptor, then re-add it
		router.push(.home)
		router.push(.details)
		router.addInterceptor(interceptor)

		// The gesture already happened — state must sync regardless
		router.path.removeLast()

		#expect(router.navigationDepth == 1)
		#expect(interceptor.navigationEvents.last == .systemPop([.details]))
	}

	// MARK: - Sheet Presentation

	@Test
	func router_presentAndDismissSheet_updatesBinding() {
		let router = TestRouter()

		router.presentSheet(.login)
		#expect(router.sheetBinding.wrappedValue == TestSheetRoute.login)
		#expect(router.presentedSheet == TestSheetRoute.login)

		router.dismissSheet()
		#expect(router.sheetBinding.wrappedValue == nil)
		#expect(router.presentedSheet == nil)
	}

	@Test
	func router_dismissSheet_whenNoSheet_emitsNoEvent() {
		let router = TestRouter()
		let interceptor = TestInterceptor()
		router.addInterceptor(interceptor)

		router.dismissSheet()

		#expect(interceptor.sheetEvents.isEmpty)
	}

	@Test
	func router_interactiveSheetDismiss_syncsStateAndNotifies() {
		let router = TestRouter()
		let interceptor = TestInterceptor()
		router.addInterceptor(interceptor)

		router.presentSheet(.login)

		// Simulate user dragging the sheet down
		router.sheetBinding.wrappedValue = nil

		#expect(router.presentedSheet == nil)
		#expect(interceptor.sheetEvents == [
			.present(.login),
			.dismiss(programmatic: false)
		])
	}

	@Test
	func router_interactiveSheetDismiss_cannotBeBlocked() {
		let router = TestRouter()
		let interceptor = TestInterceptor()
		router.addInterceptor(interceptor)

		router.presentSheet(.login)
		interceptor.shouldAllowSheet = false // would block programmatic dismiss

		// The drag gesture already removed the sheet from screen —
		// blocking would desync router state from reality.
		router.sheetBinding.wrappedValue = nil

		#expect(router.presentedSheet == nil)
		#expect(interceptor.sheetEvents.last == .dismiss(programmatic: false))
	}

	@Test
	func router_programmaticSheetDismiss_canBeBlocked() {
		let router = TestRouter()
		let interceptor = TestInterceptor()
		router.addInterceptor(interceptor)

		router.presentSheet(.login)
		interceptor.shouldAllowSheet = false

		router.dismissSheet()

		// Programmatic dismiss respects the interceptor
		#expect(router.presentedSheet == TestSheetRoute.login)
	}

	// MARK: - Full Screen Cover Presentation

	@Test
	func router_presentAndDismissFullScreenCover_updatesBinding() {
		let router = TestRouter()

		router.presentFullScreenCover(.login)
		#expect(router.fullScreenCoverBinding.wrappedValue == TestCoverRoute.login)

		router.dismissFullScreenCover()
		#expect(router.fullScreenCoverBinding.wrappedValue == nil)
	}

	@Test
	func router_interactiveCoverDismiss_syncsStateAndNotifies() {
		let router = TestRouter()
		let interceptor = TestInterceptor()
		router.addInterceptor(interceptor)

		router.presentFullScreenCover(.login)
		router.fullScreenCoverBinding.wrappedValue = nil

		#expect(router.presentedFullScreenCover == nil)
		#expect(interceptor.coverEvents == [
			.present(.login),
			.dismiss(programmatic: false)
		])
	}

	// MARK: - Dismiss All

	@Test
	func router_dismissAll_closesModalsAndPopsToRoot() {
		let router = TestRouter()

		router.push(.home)
		router.push(.details)
		router.presentSheet(.login)
		router.presentFullScreenCover(.login)

		router.dismissAll()

		#expect(router.presentedSheet == nil)
		#expect(router.presentedFullScreenCover == nil)
		#expect(router.navigationDepth == 0)
		#expect(router.path.count == 0)
	}

	// MARK: - Interceptors

	@Test
	func router_navigationInterceptor_canBlockNavigation() {
		let router = TestRouter()
		let interceptor = TestInterceptor()
		interceptor.shouldAllowNavigation = false
		router.addInterceptor(interceptor)

		router.push(.home)

		#expect(router.navigationDepth == 0) // blocked
		#expect(router.path.count == 0)
		#expect(interceptor.navigationEvents.isEmpty) // didProcess should not be called
	}

	@Test
	func router_navigationInterceptor_receivesEventsOnSuccess() {
		let router = TestRouter()
		let interceptor = TestInterceptor()
		router.addInterceptor(interceptor)

		router.push(.home)
		router.push(.details)
		router.pop()
		router.popToRoot()

		#expect(interceptor.navigationEvents == [
			.push(.home, strategy: .always),
			.push(.details, strategy: .always),
			.pop,
			.popToRoot
		])
	}

	@Test
	func router_sheetInterceptor_canBlockPresentation() {
		let router = TestRouter()
		let interceptor = TestInterceptor()
		interceptor.shouldAllowSheet = false
		router.addInterceptor(interceptor)

		router.presentSheet(.login)

		#expect(router.sheetBinding.wrappedValue == nil)
		#expect(interceptor.sheetEvents.isEmpty)
	}

	@Test
	func router_coverInterceptor_canBlockPresentation() {
		let router = TestRouter()
		let interceptor = TestInterceptor()
		interceptor.shouldAllowCover = false
		router.addInterceptor(interceptor)

		router.presentFullScreenCover(.login)

		#expect(router.fullScreenCoverBinding.wrappedValue == nil)
		#expect(interceptor.coverEvents.isEmpty)
	}

	@Test
	func router_removeInterceptor_onlyRemovesThatOne() {
		let router = TestRouter()
		let blocking = TestInterceptor()
		blocking.shouldAllowNavigation = false
		let observing = TestInterceptor()

		let blockingToken = router.addInterceptor(blocking)
		router.addInterceptor(observing)

		router.push(.home)
		#expect(router.navigationDepth == 0) // blocked

		router.removeInterceptor(blockingToken)
		router.push(.home)

		#expect(router.navigationDepth == 1) // no longer blocked
		#expect(observing.navigationEvents == [.push(.home, strategy: .always)]) // observer survived
	}

	@Test
	func router_clearInterceptors_removesAll() {
		let router = TestRouter()
		let interceptor = TestInterceptor()
		interceptor.shouldAllowNavigation = false
		router.addInterceptor(interceptor)

		router.clearInterceptors()
		router.push(.home)

		#expect(router.navigationDepth == 1)
		#expect(router.currentRoute == .home)
	}

	// MARK: - State Restoration

	@Test
	func router_stateRestoration_roundTrip() throws {
		let router = TestRouter()
		router.push(.home)
		router.push(.details)
		router.push(.settings)

		let data = try router.encodedStack()

		let restored = TestRouter()
		try restored.restoreStack(from: data)

		#expect(restored.routesFromRoot == [.home, .details, .settings])
		#expect(restored.path.count == 3)
		#expect(restored.currentRoute == .settings)
	}

	@Test
	func router_stateRestoration_goesThroughInterceptors() throws {
		let router = TestRouter()
		router.push(.settings)
		let data = try router.encodedStack()

		let restored = TestRouter()
		let guard_ = TestInterceptor()
		guard_.shouldAllowNavigation = false
		restored.addInterceptor(guard_)

		try restored.restoreStack(from: data)

		// Auth-guard-style interceptor may block restoring into protected screens
		#expect(restored.navigationDepth == 0)
	}
}
