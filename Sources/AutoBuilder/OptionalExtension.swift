extension Optional: Buildable {
    public init(with builder: Builder) throws {
        if let value = try builder.build() {
            self.init(value)
        } else {
            self.init(nilLiteral: ())
        }
    }

    public func toBuilder() -> Builder {
        return Builder()
    }

    public class Builder: BuilderProtocol {
        public let wrappedValue: BuildableOptionalProperty<Wrapped>

        public required init() {
            wrappedValue = BuildableOptionalProperty(name: "wrappedValue")
        }

        @discardableResult
        public func set(value: Wrapped?) -> Builder {
            wrappedValue.set(value: value)
            return self
        }

        public func build() throws -> Optional {
            return try wrappedValue.build()
        }
    }
}
