public protocol BuilderProtocol: AnyObject {
    associatedtype Client
    init()
    func build() throws -> Client
}
