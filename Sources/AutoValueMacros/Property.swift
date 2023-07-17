import SwiftSyntax

struct Property: Equatable, CustomStringConvertible {
    let bindingKeyword: BindingKeyword
    let identifierPattern: IdentifierPatternSyntax
    let type: String

    var identifier: String {
        return identifierPattern.identifier.text
    }

    var identifierToken: TokenSyntax {
        return .identifier(identifier)
    }

    var description: String {
        return "(\(identifier), \(type))"
    }

    init(bindingKeyword: BindingKeyword, identifier: String, type: String) {
        let identifierPattern = IdentifierPatternSyntax(identifier: .identifier(identifier))
        self.init(bindingKeyword: bindingKeyword, identifierPattern: identifierPattern, type: type)
    }

    init(bindingKeyword: BindingKeyword, identifierPattern: IdentifierPatternSyntax, type: String) {
        self.bindingKeyword = bindingKeyword
        self.identifierPattern = identifierPattern
        self.type = type
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
