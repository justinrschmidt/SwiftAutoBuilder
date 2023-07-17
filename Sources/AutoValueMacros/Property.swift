import SwiftSyntax

struct Property: Equatable, CustomStringConvertible {
    let bindingKeyword: BindingKeyword
    let identifierPattern: IdentifierPatternSyntax
    let typeNode: TypeSyntax

    var identifier: String {
        return identifierPattern.identifier.text
    }

    var type: String {
        return typeNode.description.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var identifierToken: TokenSyntax {
        return .identifier(identifier)
    }

    var description: String {
        return "(\(identifier), \(type))"
    }

    init(bindingKeyword: BindingKeyword, identifierPattern: IdentifierPatternSyntax, typeNode: TypeSyntax) {
        self.bindingKeyword = bindingKeyword
        self.identifierPattern = identifierPattern
        self.typeNode = typeNode
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
}
