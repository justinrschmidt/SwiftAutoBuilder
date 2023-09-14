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
        return variableType.type
    }

    var isInitializedConstant: Bool {
        return bindingKeyword == .let && isInitialized
    }

    var description: String {
        let stored = isStoredProperty ? "stored" : "computed"
        let iVar = isIVar ? "iVar" : "static"
        let initialized = isInitialized ? "initialized" : "uninitialized"
        return "(\(stored), \(iVar), \(identifier), \(variableType), \(initialized))"
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
}
