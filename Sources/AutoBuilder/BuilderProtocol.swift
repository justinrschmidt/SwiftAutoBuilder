/// A class that can initialize it's `Client` type.
///
/// All types that have the `@Buildable` macro attached to them are given
/// a nested `Builder` class that conforms to `BuilderProtocol`. The
/// type that has the `@Buildable` macro attached to it is referred to as
/// the builder's "client".
public protocol BuilderProtocol: AnyObject {

    /// The type of this builder's client.
    associatedtype Client

    /// Initialize the builder.
    init()

    /// Initialize the client type.
    /// - Returns: An instance of this builder's client.
    /// - Throws: `BuilderError.missingValue` if the builder is missing
    /// any values that are needed to build an instance of `Client`.
    func build() throws -> Client
}
