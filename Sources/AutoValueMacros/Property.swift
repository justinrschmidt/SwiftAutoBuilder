import SwiftSyntax

struct Property: Equatable, CustomStringConvertible {
    let bindingKeyword: BindingKeyword
    let identifierPattern: IdentifierPatternSyntax
    let variableType: VariableType

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

    var identifierToken: TokenSyntax {
        return .identifier(identifier)
    }

    var description: String {
        return "(\(identifier), \(type))"
    }

    init(bindingKeyword: BindingKeyword, identifierPattern: IdentifierPatternSyntax, type: VariableType) {
        self.bindingKeyword = bindingKeyword
        self.identifierPattern = identifierPattern
        self.variableType = type
    }

    static func ==(lhs: Property, rhs: Property) -> Bool {
        guard lhs.bindingKeyword == rhs.bindingKeyword else { return false }
        guard lhs.identifier == rhs.identifier else { return false }
        guard lhs.type == rhs.type else { return false }
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

    enum VariableType {
        case implicit
        case explicit(typeNode: TypeSyntax)
    }
}
