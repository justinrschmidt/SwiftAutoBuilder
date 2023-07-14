import SwiftSyntax

struct Property: Equatable, CustomStringConvertible {
    let bindingKeyword: BindingKeyword
    let identifier: String
    let type: String

    var identifierToken: TokenSyntax {
        return .identifier(identifier)
    }

    var description: String {
        return "(\(identifier), \(type))"
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
