import SwiftSyntax

struct EnumUnionCase: Equatable, CustomStringConvertible {
    let caseIdentifierPattern: IdentifierPatternSyntax
    let associatedValues: [Property]

    var caseIdentifier: String {
        return caseIdentifierPattern.identifier.text
    }

    var capitalizedCaseIdentifier: String {
        let text = caseIdentifier
        guard !text.isEmpty else {
            return ""
        }
        return text.first!.uppercased() + text[text.index(after: text.startIndex)...]
    }

    var description: String {
        return "(\(caseIdentifier), \(associatedValues)"
    }

    static func ==(lhs: EnumUnionCase, rhs: EnumUnionCase) -> Bool {
        guard lhs.caseIdentifier == rhs.caseIdentifier else { return false }
        guard lhs.associatedValues == rhs.associatedValues else { return false }
        return true
    }
}
