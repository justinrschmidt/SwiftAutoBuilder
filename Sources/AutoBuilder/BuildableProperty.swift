public protocol Buildable {
    associatedtype Builder
    init(with builder: Builder) throws
    func toBuilder() -> Builder
}

public protocol BuilderProtocol: AnyObject {
    associatedtype Client
    init()
    func build() throws -> Client
}

public class BuildableProperty<T> {
    private let propertyName: String
    private var value: T?
    private var subBuilder: Optional<any BuilderProtocol>

    public init(_ value: T? = nil, name: String) {
        propertyName = name
        self.value = value
        subBuilder = nil
    }

    public func set(value: T) {
        subBuilder = nil
        self.value = value
    }

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

public enum BuilderError: Error {
    case missingValue(propertyName: String)
}

extension BuildableProperty where T: Buildable, T.Builder: BuilderProtocol, T.Builder.Client == T {
    public var builder: T.Builder {
        get {
            if let subBuilder = self.subBuilder as? T.Builder {
                return subBuilder
            } else {
                let subBuilder = value?.toBuilder() ?? T.Builder()
                value = nil
                self.subBuilder = subBuilder
                return subBuilder
            }
        }
        set {
            value = nil
            subBuilder = newValue
        }
    }
}

// MARK: - Collection Properties

public class BuildableArrayProperty<Element> {
    private var array: [Element]

    public init() {
        array = []
    }

    public func set(value: [Element]) {
        array = value
    }

    public func append(element: Element) {
        array.append(element)
    }

    public func append<C>(contentsOf collection: C) where C: Collection, C.Element == Element {
        array.insert(contentsOf: collection, at: array.endIndex)
    }

    public func removeAll() {
        array.removeAll()
    }

    public func build() -> [Element] {
        return array
    }
}

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

public class BuildableSetProperty<Element> where Element: Hashable {
    private var set: Set<Element>

    public init() {
        set = []
    }

    public func set(value: Set<Element>) {
        set = value
    }

    public func insert(element: Element) {
        set.insert(element)
    }

    public func formUnion(other: Set<Element>) {
        set.formUnion(other)
    }

    public func removeAll() {
        set.removeAll()
    }

    public func build() -> Set<Element> {
        return set
    }
}
