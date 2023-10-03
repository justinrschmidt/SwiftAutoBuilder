enum InitializedStatus {
    case initialized
    case uninitialized

    var isInitialized: Bool {
        switch self {
        case .initialized:
            return true
        case .uninitialized:
            return false
        }
    }
}
