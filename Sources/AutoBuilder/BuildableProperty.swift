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
        if let subBuilder = self.subBuilder as? T.Builder {
            return subBuilder
        } else {
            value = nil
            let subBuilder = T.Builder()
            self.subBuilder = subBuilder
            return subBuilder
        }
    }
}
