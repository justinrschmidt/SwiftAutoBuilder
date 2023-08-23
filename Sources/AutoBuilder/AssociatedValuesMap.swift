public struct AssociatedValuesMap {
    private var values: [Key:Any]

    public subscript<T>(_ label: String, _ type: T.Type) -> T? {
        return values[.label(label)] as? T
    }

    public subscript<T>(_ index: Int, _ type: T.Type) -> T? {
        return values[.index(index)] as? T
    }

    public init() {
        values = [:]
    }

    public mutating func set(_ value: Any, for label: String) {
        values[.label(label)] = value
    }

    public mutating func set(_ value: Any, for index: Int) {
        values[.index(index)] = value
    }

    private enum Key: Equatable, Hashable {
        case label(String)
        case index(Int)
    }
}
