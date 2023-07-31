/// A type that can be initialized from a builder and can be converted into a builder.
///
/// All types that have the `@AutoBuilder` macro attached to them conform to `Buildable`.
public protocol Buildable {

    /// The builder's type.
    associatedtype Builder

    /// Initialize the type from its builder.
    /// - Parameters:
    ///   - builder: The builder that the type will be initialized from.
    init(with builder: Builder) throws

    /// Create a builder using the values from this type.
    /// - Returns: The builder that is created from this type.
    func toBuilder() -> Builder
}
