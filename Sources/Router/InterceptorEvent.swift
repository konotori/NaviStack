//
//  InterceptorEvent.swift
//  
//
//  Created by Amitayus on 12/11/25.
//

// MARK: - Navigation Event

public enum NavigationEvent<Route: Hashable> {
	case push(Route, strategy: PushStrategy)
	case pop
	case popTo(Route)
	case popToRoot
	case replace(Route)
}

public enum PushStrategy {
	case always
	case ifNotExists
	case navigateOrPush
}

// MARK: - Presentation Event

public enum PresentationEvent<Route: Identifiable> {
	case presentSheet(Route)
	case presentFullScreenCover(Route)
	case dismissSheet
	case dismissFullScreenCover
}
