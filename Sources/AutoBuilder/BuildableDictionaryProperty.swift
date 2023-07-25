public class BuildableDictionaryProperty<Key, Value> where Key: Hashable {
    private var dictionary: [Key:Value]

    public init() {
        dictionary = [:]
    }

    public func set(value: [Key:Value]) {
        dictionary = value
    }

    public func insert(key: Key, value: Value) {
        dictionary[key] = value
    }

    public func merge(other: [Key:Value], uniquingKeysWith combine: (Value, Value) throws -> Value) rethrows {
        try dictionary.merge(other, uniquingKeysWith: combine)
    }

    public func removeAll() {
        dictionary.removeAll()
    }

    public func build() -> [Key:Value] {
        return dictionary
    }
}
