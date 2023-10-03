import SwiftSyntax

struct Property: Equatable, CustomStringConvertible {
    let isStoredProperty: Bool
    let isIVar: Bool
    let bindingKeyword: BindingKeyword
    let identifierPattern: IdentifierPatternSyntax
    let variableType: VariableType
    let isInitialized: Bool

    var isInitializedConstant: Bool {
        return bindingKeyword == .let && isInitialized
    }

    var description: String {
        let stored = isStoredProperty ? "stored" : "computed"
        let iVar = isIVar ? "iVar" : "static"
        let initialized = isInitialized ? "initialized" : "uninitialized"
        return "(\(stored), \(iVar), \(identifierPattern.identifier.text), \(variableType), \(initialized))"
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
        guard lhs.identifierPattern.identifier.text == rhs.identifierPattern.identifier.text else { return false }
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
}
