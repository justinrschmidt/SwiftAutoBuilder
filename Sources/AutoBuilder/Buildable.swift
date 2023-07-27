public protocol Buildable {
    associatedtype Builder
    init(with builder: Builder) throws
    func toBuilder() -> Builder
}
