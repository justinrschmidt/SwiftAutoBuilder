/// Used to store the value of a property in a builder. When the builder builds, the properties in the client type
/// are initialized to the values stored in the builder's `BuildableProperty`s. `T` is the type of the
/// property in the client type.
///
/// When `T` conforms to `Buildable` (any type with `@Buildable` attached to it conforms to
/// `Buildable`), `BuildableProperty` can store either an instance of type `T`, or an instance
/// of the builder for `T` (ie: `T.Builder`). This enables builder chaining syntax. ex:
///
///     @Buildable
///     struct A {
///         var value: Int
///     }
///
///     @Buildable
///     struct B {
///         var a: A
///     }
///
///     let bBuilder = B.Builder()
///     bBuilder.a.builder.set(value: 42)
///     let b = try bBuilder.build()
///     print(b.a.value)
///     // Prints "42"
///
/// - SeeAlso:
///   - `BuildableArrayProperty`
///   - `BuildableDictionaryProperty`
///   - `BuildableSetProperty`
public class BuildableProperty<T> {

    /// The name of the property in the client type that this `BuildableProperty` is associated with.
    /// The property name is used to provide more meaningful errors.
    private let propertyName: String

    /// The value that the client's property will be initialized to when this builder builds.
    private var value: T?

    /// The builder of type `T.Builder`. The client's property will be initialized to the value
    /// created by building `subBuilder`.
    private var subBuilder: Optional<any BuilderProtocol>

    /// Initialize the `BuildableProperty`.
    /// - Parameters:
    ///   - name: The name of the client's property that this `BuildableProperty` is associated with.
    public init(name: String) {
        propertyName = name
        value = nil
        subBuilder = nil
    }

    /// Sets the value that the client's property will be initialized to.
    /// - Parameters:
    ///   - value: The value that the client's property will be initialized to.
    ///
    /// If values have been set on this `BuildableProperty`'s sub-builder via builder chaining,
    /// the sub-builder will be destroyed and those previously set values will be replaced by the
    /// value passed into this method.
    ///
    /// If `value` conforms to `Buildable`, `value`'s `toBuilder()` method will be called
    /// and the resulting builder will be used as this `BuildableProperty`'s sub-builder.
    public func set(value: T) {
        if let buildableValue = value as? any Buildable {
            subBuilder = buildableValue.toBuilder() as any BuilderProtocol
            self.value = nil
        } else {
            subBuilder = nil
            self.value = value
        }
    }

    /// Returns the value that the client's property should be initialized to.
    /// - Returns: The value that the client's property should be initialized to.
    /// - Throws: `BuilderError.missingValue` if this `BuildableProperty`'s
    /// value has not been set and no sub-builder is being used, OR if a sub-builder is being
    /// used and any value is not set in the sub-builder.
    ///
    /// If the value of this `BuildableProperty` was set via a call to `set(value:)`,
    /// then the value passed into that method will be returned. If values were set in the
    /// sub-builder via builder chaining, then the value returned from the sub-builder's
    /// `build()` method will be returned.
    public func build() throws -> T {
        if let value = value {
            return value
        } else if let value = try subBuilder?.build() as? T {
            return value
        } else {
            throw BuilderError.missingValue(propertyName: propertyName)
        }
    }
}

extension BuildableProperty where T: Buildable {
    /// The nested sub-builder that can be used for builder chaining when `T` conforms to `Buildable`.
    ///
    /// When `builder` is accessed by `get` and the value of this `BuildableProperty` has already been set
    /// with `set(value:)`, that value's `toBuilder()` method will be called and that builder will be returned.
    ///
    /// When `builder` is accessed by `set` and the value of this `BuildableProperty` has already been set
    /// with `set(value:)`, that value will be destroyed and replaced by the builder that is assigned to `builder`.
    public var builder: T.Builder {
        get {
            if let subBuilder = self.subBuilder.flatMap({ $0 as? T.Builder }) {
                return subBuilder
            } else {
                let subBuilder = T.Builder()
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
