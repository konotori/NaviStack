//
//  InterceptorEvent.swift
//
//
//  Created by Amitayus on 12/11/25.
//

// MARK: - Navigation Event

/// Events emitted for stack-based navigation.
///
/// All cases except ``systemPop(_:)`` flow through both
/// `Interceptor.shouldProcess` (blockable) and `Interceptor.didProcess`.
/// ``systemPop(_:)`` is emitted when the **system** removes routes
/// (back-swipe gesture, navigation bar back button, long-press back menu).
/// It cannot be blocked — by the time the router observes it, the
/// transition has already happened — so it is only delivered to
/// `Interceptor.didProcess`.
public enum NavigationEvent<Route: Hashable> {
	case push(Route, strategy: PushStrategy)
	case pop
	case popTo(Route)
	case popToRoot
	case replace(Route)
	/// The entire stack was replaced atomically (deep links, state restoration).
	case setStack([Route])
	/// Routes removed by a system interaction (back swipe, back button).
	/// Delivered to `didProcess` only; never blockable.
	case systemPop([Route])
}

extension NavigationEvent: Equatable {}
extension NavigationEvent: Sendable where Route: Sendable {}

public enum PushStrategy: Sendable, Hashable {
	case always
	case ifNotExists
	case navigateOrPush
}

// MARK: - Presentation Events

/// Events emitted for sheet presentation.
public enum SheetEvent<Route: Identifiable> {
	case present(Route)
	/// Dismissal. `programmatic` is `false` when triggered by an interactive
	/// gesture (drag-to-dismiss) — gesture dismissals are already complete
	/// when observed and are delivered to `didProcess` only.
	case dismiss(programmatic: Bool)
}

extension SheetEvent: Equatable where Route: Equatable {}
extension SheetEvent: Sendable where Route: Sendable {}

/// Events emitted for full-screen cover presentation.
public enum CoverEvent<Route: Identifiable> {
	case present(Route)
	/// Dismissal. `programmatic` is `false` when triggered by an interactive
	/// gesture — gesture dismissals are already complete when observed and
	/// are delivered to `didProcess` only.
	case dismiss(programmatic: Bool)
}

extension CoverEvent: Equatable where Route: Equatable {}
extension CoverEvent: Sendable where Route: Sendable {}
