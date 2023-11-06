/// A variant of `BuildableProperty` that is used when the client's property is an `Optional`.
///
/// This class's `Wrapped` type is the same type of the client's `Optional.Wrapped` type.
///
/// When `Wrapped` conforms to `Buildable` (any type with `@Buildable` attached to it conforms to `Buildable`),
/// `BuildableOptionalProperty` will store an instance of `Wrapped.Builder` as its sub-builder.
///
/// - SeeAlso:
///   - `BuildableProperty`
///   - `BuildableArrayProperty`
///   - `BuildableDictionaryProperty`
///   - `BuildableSetProperty`
public class BuildableOptionalProperty<Wrapped> {

    /// The name of the property in the client type that this `BuildableOptionalProperty` is associated with.
    private let propertyName: String

    /// The value that the client's property will be initialized to when this builder builds.
    ///
    /// `value` is only used when `Wrapped` does not conform to `Buildable`.
    private var value: Wrapped?

    /// The builder of type `Wrapped.Builder`. The client's property will be initialized to the value created by
    /// building `subBuilder`.
    ///
    /// `subBuilder` is only used when `Wrapped` conforms to `Buildable`.
    private var subBuilder: Optional<any BuilderProtocol>

    /// Initialize the `BuildableOptionalProperty`.
    /// - Parameters:
    ///   - name: The name of the client's property that this `BuildableOptionalProperty` is associated with.
    public init(name: String) {
        propertyName = name
        value = nil
        subBuilder = nil
    }

    /// Sets the value that the client's property will be initialized to.
    /// - Parameters:
    ///   - value: The value that the client's property will be initialized to.
    ///
    /// If `value` conforms to `Buildable`, `value`'s `toBuilder()` method will be called and the resulting builder will
    /// be used as this `BuildableOptionalProperty`'s sub-builder.
    public func set(value: Wrapped?) {
        if let buildableValue = value.flatMap({ $0 as? any Buildable }) {
            subBuilder = buildableValue.toBuilder() as any BuilderProtocol
            self.value = nil
        } else {
            subBuilder = nil
            self.value = value
        }
    }

    /// Returns the value that the client's property should be initialized to.
    /// - Returns: The value that the client's property should be initialized to.
    /// - Throws: If `Wrapped` conforms to `Buildable`, this method will throw any errors thrown by
    /// `Wrapped.Builder.build()`.
    ///
    /// If `Wrapped` conforms to `Buildable`, then the value returned by this method will be the result of calling the
    /// sub-builder's `build()` method.
    public func build() throws -> Wrapped? {
        return try value ?? subBuilder?.build() as? Wrapped
    }
}

extension BuildableOptionalProperty where Wrapped: Buildable {
    /// The nested sub-builder that can be used for builder chaining when `Wrapped` conforms to `Buildable`.
    ///
    /// Calling `get` will return the existing sub-builder. If no sub-builder already exists, then a new sub-builder
    /// will be created for this `BuildableOptionalProperty` and the new sub-builder will be returned.
    ///
    /// Calling `set` will replace the existing sub-builder with the value assigned to this property.
    public var builder: Wrapped.Builder {
        get {
            if let subBuilder = self.subBuilder.flatMap({ $0 as? Wrapped.Builder }) {
                return subBuilder
            } else {
                let subBuilder = Wrapped.Builder()
                self.subBuilder = subBuilder
                value = nil
                return subBuilder
            }
        }
        set {
            value = nil
            subBuilder = newValue
        }
    }
}
