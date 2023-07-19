public protocol Buildable {}
public protocol BuilderProtocol: AnyObject {}
public class BuildableProperty<T> {
    private let propertyName: String
    private var value: T?

    public init(_ value: T? = nil, name: String) {
        propertyName = name
        self.value = value
    }

    public func set(value: T) {
        self.value = value
    }

    public func build() throws -> T {
        guard let value = value else {
            throw BuilderError.missingValue(propertyName: propertyName)
        }
        return value
    }
}

public enum BuilderError: Error {
    case missingValue(propertyName: String)
}
