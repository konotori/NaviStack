//
//  Interceptor.swift
//
//
//  Created by Amitayus on 12/11/25.
//

import SwiftUI
import Combine

@MainActor
open class BaseRouter<NavRoute: Hashable, SheetRoute: Identifiable, CoverRoute: Identifiable>: ObservableObject {
	// MARK: - States
	
	@Published public var path = NavigationPath()
	@Published private var globalSheet: SheetRoute?
	@Published private var globalFullScreenCover: CoverRoute?
	private var routeStack: [NavRoute] = []
	private var pathChangeCancellable: AnyCancellable?
	private var interceptors: [any Interceptor<NavRoute, SheetRoute, CoverRoute>] = []
	
	public var sheetBinding: Binding<SheetRoute?> {
		Binding(
			get: { self.globalSheet },
			set: { [weak self] newValue in
				guard let self else {
					return
				}
				
				if newValue == nil, self.globalSheet != nil {
					// Dismiss gesture or manual nil
					dismissSheet()
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
					// Dismiss gesture or manual nil
					self.dismissFullScreenCover()
				}
			}
		)
	}
	
	// MARK: - Init
	
	public init() {
		setupPathObserver()
	}
	
	// MARK: - Public Properties
	
	public var currentRoute: NavRoute? {
		routeStack.last
	}
	
	public var currentRouteName: String {
		currentRoute.map { String(describing: $0) } ?? "Root"
	}
	
	public var routeHistory: [NavRoute] {
		routeStack
	}
	
	public var navigationDepth: Int {
		routeStack.count
	}
	
	public var canPop: Bool {
		!routeStack.isEmpty && !path.isEmpty
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
				path.append(route)
				routeStack.append(route)
				
			case .ifNotExists:
				if !containsRoute(route) {
					path.append(route)
					routeStack.append(route)
				}
				
			case .navigateOrPush:
				if let existingIndex = routeStack.firstIndex(of: route) {
					navigateToExisting(at: existingIndex)
				} else {
					path.append(route)
					routeStack.append(route)
				}
			}
		}
	}
	
	public func pop() {
		guard canPop else {
			#if DEBUG
			print("⚠️ Navigation: pop() ignored - empty stack")
			#endif
			return
		}
		
		processNavigationInterceptor(event: .pop) {
			path.removeLast()
		}
	}
	
	public func popTo(_ route: NavRoute) {
		guard let index = routeStack.firstIndex(of: route) else {
			#if DEBUG
			print("⚠️ Navigation: popTo() ignored - route not found: \(route)")
			#endif
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
			path.removeLast(path.count)
		}
	}
	
	public func replace(with route: NavRoute) {
		processNavigationInterceptor(event: .replace(route)) {
			if canPop {
				path.removeLast()
			}
			path.append(route)
			routeStack.append(route)
		}
	}
	
	public func presentSheet(_ route: SheetRoute) {
		processSheetPresentationInterceptor(event: .presentSheet(route)) {
			globalSheet = route
		}
	}
	
	public func dismissSheet() {
		processSheetPresentationInterceptor(event: .dismissSheet) {
			globalSheet = nil
		}
	}
	
	public func presentFullScreenCover(_ route: CoverRoute) {
		processCoverPresentationInterceptor(event: .presentFullScreenCover(route)) {
			globalFullScreenCover = route
		}
	}
	
	public func dismissFullScreenCover() {
		processCoverPresentationInterceptor(event: .dismissFullScreenCover) {
			globalFullScreenCover = nil
		}
	}
	
	// MARK: - Public Query Methods
	
	public func isCurrentRoute(_ route: NavRoute) -> Bool {
		currentRoute == route
	}
	
	public func containsRoute(_ route: NavRoute) -> Bool {
		routeStack.contains(route)
	}
	
	// MARK: - Public Interceptor Management Methods
	
	public func addInterceptor<M: Interceptor>(_ Interceptor: M)
	where M.NavRoute == NavRoute,
		  M.SheetRoute == SheetRoute,
		  M.CoverRoute == CoverRoute
	{
		interceptors.append(Interceptor)
	}
	
	public func clearInterceptors() {
		interceptors.removeAll()
	}
	
	// MARK: - Private Navigation Methods
	
	private func navigateToExisting(at index: Int) {
		guard index < routeStack.count - 1 else {
			return
		}
		
		let routesToPop = routeStack.count - index - 1
		path.removeLast(routesToPop)
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
		for interceptor in interceptors {
			guard interceptor.shouldProcess(event, for: self) else {
				#if DEBUG
				print("🚫 Navigation: blocked by \(type(of: interceptor))")
				#endif
				return false
			}
		}
		return true
	}
	
	private func didProcessNavigation(_ event: NavigationEvent<NavRoute>) {
		for interceptor in interceptors {
			interceptor.didProcess(event, for: self)
		}
	}
	
	// MARK: - Private Sheet Presentation Interceptor Helpers
	
	private func processSheetPresentationInterceptor(event: PresentationEvent<SheetRoute>, handler: () -> Void) {
		guard shouldProcessSheetPresentation(event) else {
			return
		}
		
		handler()
		didProcessSheetPresentation(event)
	}
	
	private func shouldProcessSheetPresentation(_ event: PresentationEvent<SheetRoute>) -> Bool {
		for interceptor in interceptors {
			guard interceptor.shouldProcess(event, for: self) else {
				#if DEBUG
				print("🚫 Sheet Presentation: blocked by \(type(of: interceptor))")
				#endif
				return false
			}
		}
		return true
	}
	
	private func didProcessSheetPresentation(_ event: PresentationEvent<SheetRoute>) {
		for interceptor in interceptors {
			interceptor.didProcess(event, for: self)
		}
	}
	
	// MARK: - Private Cover Presentation Interceptor Helpers
	
	private func processCoverPresentationInterceptor(event: PresentationEvent<CoverRoute>, handler: () -> Void) {
		guard shouldProcessCoverPresentation(event) else {
			return
		}
		
		handler()
		didProcessCoverPresentation(event)
	}
	
	private func shouldProcessCoverPresentation(_ event: PresentationEvent<CoverRoute>) -> Bool {
		for interceptor in interceptors {
			guard interceptor.shouldProcess(event, for: self) else {
				#if DEBUG
				print("🚫 Cover Presentation: blocked by \(type(of: interceptor))")
				#endif
				return false
			}
		}
		return true
	}
	
	private func didProcessCoverPresentation(_ event: PresentationEvent<CoverRoute>) {
		for interceptor in interceptors {
			interceptor.didProcess(event, for: self)
		}
	}
	
	// MARK: - Path Synchronization
	
	private func setupPathObserver() {
		pathChangeCancellable = $path
			.dropFirst()
			.sink { [weak self] newPath in
				self?.syncRouteStack(with: newPath)
			}
	}
	
	private func syncRouteStack(with path: NavigationPath) {
		let pathCount = path.count
		let stackCount = routeStack.count
		
		if pathCount < stackCount {
			let difference = stackCount - pathCount
			routeStack.removeLast(difference)
		}
	}
}
