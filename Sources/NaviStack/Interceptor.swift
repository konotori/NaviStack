//
//  Interceptor.swift
//
//
//  Created by Amitayus on 12/11/25.
//

import Foundation

/// Interceptor protocol with two-phase processing.
///
/// The protocol is `@MainActor` so that conformers can freely read router
/// state (`router.currentRoute`, `router.navigationDepth`, …) and trigger
/// follow-up navigation (`router.presentFullScreenCover(...)`) — all of
/// which is MainActor-isolated. Conforming types are inferred to be
/// `@MainActor` automatically.
///
/// - `shouldProcess` is called **before** the action and can block it by
///   returning `false`. It is never called for events that cannot be
///   blocked (`NavigationEvent.systemPop`, gesture-driven dismissals).
/// - `didProcess` is called **after** the action succeeded — use it for
///   side effects such as analytics or logging.
@MainActor
public protocol Interceptor<NavRoute, SheetRoute, CoverRoute> {
	associatedtype NavRoute: Hashable
	associatedtype SheetRoute: Identifiable
	associatedtype CoverRoute: Identifiable

	/// Called BEFORE navigation. Return false to block.
	func shouldProcess(_ event: NavigationEvent<NavRoute>, for router: BaseRouter<NavRoute, SheetRoute, CoverRoute>) -> Bool

	/// Called AFTER navigation succeeds (for side effects).
	func didProcess(_ event: NavigationEvent<NavRoute>, for router: BaseRouter<NavRoute, SheetRoute, CoverRoute>)

	/// Called BEFORE sheet presentation/programmatic dismissal. Return false to block.
	func shouldProcess(_ event: SheetEvent<SheetRoute>, for router: BaseRouter<NavRoute, SheetRoute, CoverRoute>) -> Bool

	/// Called AFTER sheet presentation/dismissal succeeds (for side effects).
	func didProcess(_ event: SheetEvent<SheetRoute>, for router: BaseRouter<NavRoute, SheetRoute, CoverRoute>)

	/// Called BEFORE cover presentation/programmatic dismissal. Return false to block.
	func shouldProcess(_ event: CoverEvent<CoverRoute>, for router: BaseRouter<NavRoute, SheetRoute, CoverRoute>) -> Bool

	/// Called AFTER cover presentation/dismissal succeeds (for side effects).
	func didProcess(_ event: CoverEvent<CoverRoute>, for router: BaseRouter<NavRoute, SheetRoute, CoverRoute>)
}

public extension Interceptor {
	func shouldProcess(_ event: NavigationEvent<NavRoute>, for router: BaseRouter<NavRoute, SheetRoute, CoverRoute>) -> Bool {
		// Default: allow all
		true
	}

	func didProcess(_ event: NavigationEvent<NavRoute>, for router: BaseRouter<NavRoute, SheetRoute, CoverRoute>) {
		// Default: do nothing
	}

	func shouldProcess(_ event: SheetEvent<SheetRoute>, for router: BaseRouter<NavRoute, SheetRoute, CoverRoute>) -> Bool {
		// Default: allow all
		true
	}

	func didProcess(_ event: SheetEvent<SheetRoute>, for router: BaseRouter<NavRoute, SheetRoute, CoverRoute>) {
		// Default: do nothing
	}

	func shouldProcess(_ event: CoverEvent<CoverRoute>, for router: BaseRouter<NavRoute, SheetRoute, CoverRoute>) -> Bool {
		// Default: allow all
		true
	}

	func didProcess(_ event: CoverEvent<CoverRoute>, for router: BaseRouter<NavRoute, SheetRoute, CoverRoute>) {
		// Default: do nothing
	}
}

/// Opaque token returned by `BaseRouter.addInterceptor(_:)`.
/// Keep it to remove the interceptor later with `removeInterceptor(_:)`.
public struct InterceptorToken: Hashable, Sendable {
	let id: UUID

	init() {
		self.id = UUID()
	}
}
