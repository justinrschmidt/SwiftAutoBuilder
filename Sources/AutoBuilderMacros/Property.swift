import SwiftSyntax

struct Property: Equatable, CustomStringConvertible {
    let isStoredProperty: Bool
    let isIVar: Bool
    let bindingKeyword: BindingKeyword
    let identifierPattern: IdentifierPatternSyntax
    let variableType: VariableType
    let isInitialized: Bool

    var identifier: String {
        return identifierPattern.identifier.text
    }

    var capitalizedIdentifier: String {
        let text = identifier
        guard !text.isEmpty else {
            return ""
        }
        return text.first!.uppercased() + text[text.index(after: text.startIndex)...]
    }

    var type: String {
        switch variableType {
        case .implicit:
            return ""
        case let .array(elementType):
            return "[\(elementType.description.trimmingCharacters(in: .whitespacesAndNewlines))]"
        case let .dictionary(keyType, valueType):
            let keyString = keyType.description.trimmingCharacters(in: .whitespacesAndNewlines)
            let valueString = valueType.description.trimmingCharacters(in: .whitespacesAndNewlines)
            return "[\(keyString):\(valueString)]"
        case let .set(elementType):
            return "Set<\(elementType.description.trimmingCharacters(in: .whitespacesAndNewlines))>"
        case let .explicit(typeNode):
            return typeNode.description.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    var isInitializedConstant: Bool {
        return bindingKeyword == .let && isInitialized
    }

    var description: String {
        let stored = isStoredProperty ? "stored" : "computed"
        let iVar = isIVar ? "iVar" : "static"
        let initialized = isInitialized ? "initialized" : "uninitialized"
        let typePrefix = switch variableType {
        case .implicit, .explicit(_): ""
        case .array(_): "A:"
        case .dictionary(_, _): "D:"
        case .set(_): "S:"
        }
        return "(\(stored), \(iVar), \(identifier), \(typePrefix)\(type), \(initialized))"
    }

    init(isStoredProperty: Bool,
         isIVar: Bool,
         bindingKeyword: BindingKeyword,
         identifierPattern: IdentifierPatternSyntax,
         type: VariableType,
         isInitialized: Bool) {
        self.isStoredProperty = isStoredProperty
        self.isIVar = isIVar
        self.bindingKeyword = bindingKeyword
        self.identifierPattern = identifierPattern
        self.variableType = type
        self.isInitialized = isInitialized
    }

    static func ==(lhs: Property, rhs: Property) -> Bool {
        guard lhs.isStoredProperty == rhs.isStoredProperty else { return false }
        guard lhs.isIVar == rhs.isIVar else { return false }
        guard lhs.bindingKeyword == rhs.bindingKeyword else { return false }
        guard lhs.identifier == rhs.identifier else { return false }
        guard lhs.variableType == rhs.variableType else { return false }
        guard lhs.isInitialized == rhs.isInitialized else { return false }
        return true
    }

    enum BindingKeyword {
        case `let`
        case `var`

        init?(kind: TokenKind) {
            switch kind {
            case TokenKind.keyword(.let):
                self = .let
            case TokenKind.keyword(.var):
                self = .var
            default:
                return nil
            }
        }
    }

    enum VariableType: Equatable {
        case implicit
        case array(elementType: TypeSyntax)
        case dictionary(keyType: TypeSyntax, valueType: TypeSyntax)
        case set(elementType: TypeSyntax)
        case explicit(typeNode: TypeSyntax)

        var isImplicit: Bool {
            switch self {
            case .implicit:
                return true
            default:
                return false
            }
        }

        var isExplicit: Bool {
            return !isImplicit
        }

        var isCollection: Bool {
            switch self {
            case .array(_), .dictionary(_, _), .set(_):
                return true
            default:
                return false
            }
        }

        static func ==(lhs: VariableType, rhs: VariableType) -> Bool {
            switch (lhs, rhs) {
            case (.implicit, .implicit):
                return true
            case let (.array(lhsType), .array(rhsType)):
                return typesAreEqual(lhsType, rhsType)
            case let (.dictionary(lhsKey, lhsValue), .dictionary(rhsKey, rhsValue)):
                return typesAreEqual(lhsKey, rhsKey) && typesAreEqual(lhsValue, rhsValue)
            case let (.set(lhsType), .set(rhsType)):
                return typesAreEqual(lhsType, rhsType)
            case let (.explicit(lhsType), .explicit(rhsType)):
                return typesAreEqual(lhsType, rhsType)
            default:
                return false
            }
        }

        private static func typesAreEqual(_ lhs: TypeSyntax, _ rhs: TypeSyntax) -> Bool {
            let lhsText = lhs.description.trimmingCharacters(in: .whitespacesAndNewlines)
            let rhsText = rhs.description.trimmingCharacters(in: .whitespacesAndNewlines)
            return lhsText == rhsText
        }
    }
}
