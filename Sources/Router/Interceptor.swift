//
//  Interceptor.swift
//  
//
//  Created by Amitayus on 12/11/25.
//

/// Interceptor protocol with two-phase processing
public protocol Interceptor<NavRoute, SheetRoute, CoverRoute> {
	associatedtype NavRoute: Hashable
	associatedtype SheetRoute: Identifiable
	associatedtype CoverRoute: Identifiable
	
	/// Called BEFORE navigation. Return false to block.
	func shouldProcess(_ event: NavigationEvent<NavRoute>, for router: BaseRouter<NavRoute, SheetRoute, CoverRoute>) -> Bool
	
	/// Called AFTER navigation succeeds (for side effects).
	func didProcess(_ event: NavigationEvent<NavRoute>, for router: BaseRouter<NavRoute, SheetRoute, CoverRoute>)
	
	/// Called BEFORE sheet presentation. Return false to block.
	func shouldProcess(_ event: PresentationEvent<SheetRoute>, for router: BaseRouter<NavRoute, SheetRoute, CoverRoute>) -> Bool
	
	/// Called AFTER sheet presentation succeeds (for side effects).
	func didProcess(_ event: PresentationEvent<SheetRoute>, for router: BaseRouter<NavRoute, SheetRoute, CoverRoute>)
	
	/// Called BEFORE cover presentation. Return false to block.
	func shouldProcess(_ event: PresentationEvent<CoverRoute>, for router: BaseRouter<NavRoute, SheetRoute, CoverRoute>) -> Bool
	
	/// Called AFTER cover presentation succeeds (for side effects).
	func didProcess(_ event: PresentationEvent<CoverRoute>, for router: BaseRouter<NavRoute, SheetRoute, CoverRoute>)
	
}

public extension Interceptor {
	func shouldProcess(_ event: NavigationEvent<NavRoute>, for router: BaseRouter<NavRoute, SheetRoute, CoverRoute>) -> Bool {
		// Default: allow all
		true
	}
	
	func didProcess(_ event: NavigationEvent<NavRoute>, for router: BaseRouter<NavRoute, SheetRoute, CoverRoute>) {
		// Default: do nothing
	}
	
	func shouldProcess(_ event: PresentationEvent<SheetRoute>, for router: BaseRouter<NavRoute, SheetRoute, CoverRoute>) -> Bool {
		// Default: allow all
		true
	}
	
	func didProcess(_ event: PresentationEvent<SheetRoute>, for router: BaseRouter<NavRoute, SheetRoute, CoverRoute>) {
		// Default: do nothing
	}
	
	func shouldProcess(_ event: PresentationEvent<CoverRoute>, for router: BaseRouter<NavRoute, SheetRoute, CoverRoute>) -> Bool {
		// Default: allow all
		true
	}
	
	func didProcess(_ event: PresentationEvent<CoverRoute>, for router: BaseRouter<NavRoute, SheetRoute, CoverRoute>) {
		// Default: do nothing
	}
}
