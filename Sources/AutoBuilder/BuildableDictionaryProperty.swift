/// A variant of `BuildableProperty` that is used when the client's property is a `Dictionary`.
///
/// This class's `Key` and `Value` types are the same types as the client property's `Dictionary.Key` and
/// `Dictionary.Value` types.
///
/// - SeeAlso:
///   - `BuildableProperty`
///   - `BuildableArrayProperty`
///   - `BuildableOptionalProperty`
///   - `BuildableSetProperty`
public class BuildableDictionaryProperty<Key, Value> where Key: Hashable {

    /// The dictionary that the client's property will be initialized to when the builder builds.
    private var dictionary: [Key: Value]

    /// Initialize the `BuildableDictionaryProperty`.
    public init() {
        dictionary = [:]
    }

    /// Sets the dictionary that the client's property will be initialized to.
    /// - Parameters:
    ///   - value: The dictionary that the client's property will be initialized to.
    public func set(value: [Key: Value]) {
        dictionary = value
    }

    /// Inserts a key-value pair into the dictionary that the client's property will be initialized to.
    /// - Parameters:
    ///   - key: The key of the key-value pair to insert into the dictionary.
    ///   - value: The value of the key-value pair to insert into the dictionary.
    public func insert(key: Key, value: Value) {
        dictionary[key] = value
    }

    /// Merges the contents of another dictionary into the dictionary that the client's property will be initialized to.
    /// - Parameters:
    ///   - other: The other dictionary that will be merged into this `BuildableDictionaryProperty`'s dictionary.
    ///   - combine: A closure that takes the current and new values for duplicate keys; the closure returns the value
    ///   that will be used in the merged dictionary.
    public func merge(other: [Key: Value], uniquingKeysWith combine: (Value, Value) throws -> Value) rethrows {
        try dictionary.merge(other, uniquingKeysWith: combine)
    }

    /// Removes all key-value pairs from the dictionary that the client's property will be initialized to.
    public func removeAll() {
        dictionary.removeAll()
    }

    /// Returns the dictionary that the client's property should be initialized to.
    /// - Returns: The dictionary that the client's property should be initialized to.
    public func build() -> [Key: Value] {
        return dictionary
    }
}
