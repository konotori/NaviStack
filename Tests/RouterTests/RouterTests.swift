import Testing
import SwiftUI
import Combine

@testable import Router

// MARK: - Test Helpers

private enum TestNavRoute: Hashable {
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

private final class TestInterceptor: Interceptor {
	typealias NavRoute = TestNavRoute
	typealias SheetRoute = TestSheetRoute
	typealias CoverRoute = TestCoverRoute
	
	var shouldAllowNavigation = true
	var shouldAllowSheet = true
	var shouldAllowCover = true
	
	private(set) var navigationEvents: [NavigationEvent<TestNavRoute>] = []
	private(set) var sheetEvents: [PresentationEvent<TestSheetRoute>] = []
	private(set) var coverEvents: [PresentationEvent<TestCoverRoute>] = []
	
	func shouldProcess(_ event: NavigationEvent<TestNavRoute>, for router: BaseRouter<TestNavRoute, TestSheetRoute, TestCoverRoute>) -> Bool {
		shouldAllowNavigation
	}
	
	func didProcess(_ event: NavigationEvent<TestNavRoute>, for router: BaseRouter<TestNavRoute, TestSheetRoute, TestCoverRoute>) {
		navigationEvents.append(event)
	}
	
	func shouldProcess(_ event: PresentationEvent<TestSheetRoute>, for router: BaseRouter<TestNavRoute, TestSheetRoute, TestCoverRoute>) -> Bool {
		shouldAllowSheet
	}
	
	func didProcess(_ event: PresentationEvent<TestSheetRoute>, for router: BaseRouter<TestNavRoute, TestSheetRoute, TestCoverRoute>) {
		sheetEvents.append(event)
	}
	
	func shouldProcess(_ event: PresentationEvent<TestCoverRoute>, for router: BaseRouter<TestNavRoute, TestSheetRoute, TestCoverRoute>) -> Bool {
		shouldAllowCover
	}
	
	func didProcess(_ event: PresentationEvent<TestCoverRoute>, for router: BaseRouter<TestNavRoute, TestSheetRoute, TestCoverRoute>) {
		coverEvents.append(event)
	}
}

// MARK: - BaseRouter Tests

@MainActor
struct BaseRouterTests {
	
	// MARK: - Base State
	
	@Test
	func router_initialState() {
		let router = BaseRouter<TestNavRoute, TestSheetRoute, TestCoverRoute>()
		
		#expect(router.navigationDepth == 0)
		#expect(router.currentRoute == nil)
		#expect(router.currentRouteName == "Root")
		#expect(router.canPop == false)
		#expect(router.routesFromRoot.isEmpty)
		#expect(router.routesToRoot.isEmpty)
		#expect(router.path.count == 0)
	}
	
	@Test
	func router_routeHistory_returnsCurrentStack() {
		let router = BaseRouter<TestNavRoute, TestSheetRoute, TestCoverRoute>()
		#expect(router.routeHistory.isEmpty)
		
		router.push(.home)
		router.push(.details)
		#expect(router.routeHistory == [.home, .details])
		
		router.pop()
		#expect(router.routeHistory == [.home])
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
		let router = BaseRouter<TestNavRoute, TestSheetRoute, TestCoverRoute>()
		
		router.push(.home)
		router.push(.details)
		
		#expect(router.navigationDepth == 2)
		#expect(router.currentRoute == .details)
		#expect(router.canPop)
		#expect(router.path.count == 2)
	}
	
	@Test
	func router_pushIfNotExists_doesNotDuplicate() {
		let router = BaseRouter<TestNavRoute, TestSheetRoute, TestCoverRoute>()
		
		router.push(.home)
		router.push(.home, strategy: .ifNotExists)
		
		#expect(router.navigationDepth == 1)
		#expect(router.path.count == 1)
		#expect(router.currentRoute == .home)
	}
	
	@Test
	func router_pushIfNotExists_appendsWhenRouteNotInStack() {
		let router = BaseRouter<TestNavRoute, TestSheetRoute, TestCoverRoute>()
		
		router.push(.home)
		router.push(.details, strategy: .ifNotExists)
		
		#expect(router.navigationDepth == 2)
		#expect(router.currentRoute == .details)
		#expect(router.routeHistory == [.home, .details])
	}
	
	@Test
	func router_pushNavigateOrPush_navigateToExisting() {
		let router = BaseRouter<TestNavRoute, TestSheetRoute, TestCoverRoute>()
		
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
		let router = BaseRouter<TestNavRoute, TestSheetRoute, TestCoverRoute>()
		
		router.push(.home)
		router.push(.settings, strategy: .navigateOrPush)
		
		#expect(router.navigationDepth == 2)
		#expect(router.currentRoute == .settings)
		#expect(router.routeHistory == [.home, .settings])
	}
	
	@Test
	func router_pop_removesTopRoute() {
		let router = BaseRouter<TestNavRoute, TestSheetRoute, TestCoverRoute>()
		
		router.push(.home)
		router.push(.details)
		router.pop()
		
		#expect(router.navigationDepth == 1)
		#expect(router.currentRoute == .home)
		#expect(router.path.count == 1)
	}
	
	@Test
	func router_pop_onEmptyDoesNothing() {
		let router = BaseRouter<TestNavRoute, TestSheetRoute, TestCoverRoute>()
		
		router.pop()
		
		#expect(router.navigationDepth == 0)
		#expect(router.path.count == 0)
	}
	
	@Test
	func router_popTo_existingRoute() {
		let router = BaseRouter<TestNavRoute, TestSheetRoute, TestCoverRoute>()
		
		router.push(.home)
		router.push(.details)
		router.push(.settings)
		
		router.popTo(.home)
		
		#expect(router.navigationDepth == 1)
		#expect(router.currentRoute == .home)
		#expect(router.path.count == 1)
	}
	
	@Test
	func router_popTo_nonExistingRouteDoesNothing() {
		let router = BaseRouter<TestNavRoute, TestSheetRoute, TestCoverRoute>()
		
		router.push(.home)
		router.push(.details)
		
		router.popTo(.settings) // not in stack
		
		#expect(router.navigationDepth == 2)
		#expect(router.currentRoute == .details)
		#expect(router.path.count == 2)
	}
	
	@Test
	func router_popTo_currentRoute_doesNothing_navigateToExistingEarlyReturn() {
		let router = BaseRouter<TestNavRoute, TestSheetRoute, TestCoverRoute>()
		
		router.push(.home)
		router.push(.details)
		router.push(.settings)
		
		// popTo current top (index == count - 1) -> navigateToExisting returns without popping
		router.popTo(.settings)
		
		#expect(router.navigationDepth == 3)
		#expect(router.currentRoute == .settings)
		#expect(router.routeHistory == [.home, .details, .settings])
	}
	
	@Test
	func router_popToRoot_clearsAll() {
		let router = BaseRouter<TestNavRoute, TestSheetRoute, TestCoverRoute>()
		
		router.push(.home)
		router.push(.details)
		
		router.popToRoot()
		
		#expect(router.navigationDepth == 0)
		#expect(router.currentRoute == nil)
		#expect(router.path.count == 0)
	}
	
	@Test
	func router_popToRoot_onEmptyStackDoesNothing() {
		let router = BaseRouter<TestNavRoute, TestSheetRoute, TestCoverRoute>()
		
		router.popToRoot()
		
		#expect(router.navigationDepth == 0)
		#expect(router.currentRoute == nil)
		#expect(router.path.count == 0)
	}
	
	// MARK: - Replace
	
	@Test
	func router_replace_onNonEmptyStackReplacesTop() {
		let router = BaseRouter<TestNavRoute, TestSheetRoute, TestCoverRoute>()
		
		router.push(.home)
		router.replace(with: .details)
		
		#expect(router.navigationDepth == 1)
		#expect(router.currentRoute == .details)
		#expect(router.path.count == 1)
	}
	
	@Test
	func router_replace_onEmptyStackJustPushes() {
		let router = BaseRouter<TestNavRoute, TestSheetRoute, TestCoverRoute>()
		
		router.replace(with: .home)
		
		#expect(router.navigationDepth == 1)
		#expect(router.currentRoute == .home)
		#expect(router.path.count == 1)
	}
	
	// MARK: - Query API
	
	@Test
	func router_queryHelpers_workAsExpected() {
		let router = BaseRouter<TestNavRoute, TestSheetRoute, TestCoverRoute>()
		
		router.push(.home)
		router.push(.details)
		
		#expect(router.isCurrentRoute(.details))
		#expect(router.containsRoute(.home))
		#expect(router.routesFromRoot == [.home, .details])
		#expect(router.routesToRoot == [.details, .home])
	}
	
	// MARK: - Path Synchronization
	
	@Test
	func router_pathObserver_keepsRouteStackInSync() {
		let router = BaseRouter<TestNavRoute, TestSheetRoute, TestCoverRoute>()
		
		router.push(.home)
		router.push(.details)
		router.push(.settings)
		
		// Simulate external change to `path` (e.g. swipe back in UI)
		router.path.removeLast()
		
		// Give Combine a moment in case this ever becomes async; currently it's synchronous.
		#expect(router.path.count == 2)
		#expect(router.navigationDepth == 2)
	}
	
	// MARK: - Sheet Presentation
	
	@Test
	func router_presentAndDismissSheet_updatesBinding() {
		let router = BaseRouter<TestNavRoute, TestSheetRoute, TestCoverRoute>()
		
		router.presentSheet(.login)
		#expect(router.sheetBinding.wrappedValue == TestSheetRoute.login)
		
		router.dismissSheet()
		#expect(router.sheetBinding.wrappedValue == nil)
	}
	
	@Test
	func router_sheetBindingSetToNil_callsDismiss() {
		let router = BaseRouter<TestNavRoute, TestSheetRoute, TestCoverRoute>()
		
		router.presentSheet(.login)
		#expect(router.sheetBinding.wrappedValue != nil)
		
		// Simulate user dragging to dismiss sheet
		router.sheetBinding.wrappedValue = nil
		
		#expect(router.sheetBinding.wrappedValue == nil)
	}
	
	// MARK: - Full Screen Cover Presentation
	
	@Test
	func router_presentAndDismissFullScreenCover_updatesBinding() {
		let router = BaseRouter<TestNavRoute, TestSheetRoute, TestCoverRoute>()
		
		router.presentFullScreenCover(.login)
		#expect(router.fullScreenCoverBinding.wrappedValue == TestCoverRoute.login)
		
		router.dismissFullScreenCover()
		#expect(router.fullScreenCoverBinding.wrappedValue == nil)
	}
	
	@Test
	func router_fullScreenCoverBindingSetToNil_callsDismiss() {
		let router = BaseRouter<TestNavRoute, TestSheetRoute, TestCoverRoute>()
		
		router.presentFullScreenCover(.login)
		#expect(router.fullScreenCoverBinding.wrappedValue != nil)
		
		// Simulate user dismissing full screen cover
		router.fullScreenCoverBinding.wrappedValue = nil
		
		#expect(router.fullScreenCoverBinding.wrappedValue == nil)
	}
	
	// MARK: - Interceptors
	
	@Test
	func router_navigationInterceptor_canBlockNavigation() {
		let router = BaseRouter<TestNavRoute, TestSheetRoute, TestCoverRoute>()
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
		let router = BaseRouter<TestNavRoute, TestSheetRoute, TestCoverRoute>()
		let interceptor = TestInterceptor()
		router.addInterceptor(interceptor)
		
		router.push(.home)
		router.push(.details)
		router.pop()
		router.popToRoot()
		
		#expect(interceptor.navigationEvents.count == 4)
	}
	
	@Test
	func router_sheetInterceptor_canBlockPresentation() {
		let router = BaseRouter<TestNavRoute, TestSheetRoute, TestCoverRoute>()
		let interceptor = TestInterceptor()
		interceptor.shouldAllowSheet = false
		router.addInterceptor(interceptor)
		
		router.presentSheet(.login)
		
		#expect(router.sheetBinding.wrappedValue == nil)
		#expect(interceptor.sheetEvents.isEmpty)
	}
	
	@Test
	func router_sheetInterceptor_receivesEventsOnSuccess() {
		let router = BaseRouter<TestNavRoute, TestSheetRoute, TestCoverRoute>()
		let interceptor = TestInterceptor()
		router.addInterceptor(interceptor)
		
		router.presentSheet(.login)
		
		#expect(interceptor.sheetEvents.count == 1)
	}
	
	@Test
	func router_coverInterceptor_canBlockPresentation() {
		let router = BaseRouter<TestNavRoute, TestSheetRoute, TestCoverRoute>()
		let interceptor = TestInterceptor()
		interceptor.shouldAllowCover = false
		router.addInterceptor(interceptor)
		
		router.presentFullScreenCover(.login)
		
		#expect(router.fullScreenCoverBinding.wrappedValue == nil)
		#expect(interceptor.coverEvents.isEmpty)
	}
	
	@Test
	func router_coverInterceptor_receivesEventsOnSuccess() {
		let router = BaseRouter<TestNavRoute, TestSheetRoute, TestCoverRoute>()
		let interceptor = TestInterceptor()
		router.addInterceptor(interceptor)
		
		router.presentFullScreenCover(.login)
		
		#expect(interceptor.coverEvents.count == 1)
	}
	
	@Test
	func router_clearInterceptors_removesAll() {
		let router = BaseRouter<TestNavRoute, TestSheetRoute, TestCoverRoute>()
		let interceptor = TestInterceptor()
		interceptor.shouldAllowNavigation = false
		router.addInterceptor(interceptor)
		
		// Clear and ensure navigation is no longer blocked
		router.clearInterceptors()
		router.push(.home)
		
		#expect(router.navigationDepth == 1)
		#expect(router.currentRoute == .home)
	}
}
