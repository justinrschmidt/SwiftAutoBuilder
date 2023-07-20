import SwiftSyntax

struct Property: Equatable, CustomStringConvertible {
    let bindingKeyword: BindingKeyword
    let identifierPattern: IdentifierPatternSyntax
    let variableType: VariableType
    let isInitialized: Bool

    var identifier: String {
        return identifierPattern.identifier.text
    }

    var type: String {
        switch variableType {
        case .implicit:
            return ""
        case .explicit(let typeNode):
            return typeNode.description.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    var isInitializedConstant: Bool {
        return bindingKeyword == .let && isInitialized
    }

    var description: String {
        let initialized = isInitialized ? "initialized" : "uninitialized"
        return "(\(identifier), \(type), \(initialized))"
    }

    init(bindingKeyword: BindingKeyword, identifierPattern: IdentifierPatternSyntax, type: VariableType, isInitialized: Bool) {
        self.bindingKeyword = bindingKeyword
        self.identifierPattern = identifierPattern
        self.variableType = type
        self.isInitialized = isInitialized
    }

    static func ==(lhs: Property, rhs: Property) -> Bool {
        guard lhs.bindingKeyword == rhs.bindingKeyword else { return false }
        guard lhs.identifier == rhs.identifier else { return false }
        guard lhs.type == rhs.type else { return false }
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
            switch self {
            case .explicit(_):
                return true
            default:
                return false
            }
        }
    }
}
