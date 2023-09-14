import SwiftSyntax
import SwiftSyntaxBuilder

struct EnumHelper {
    static func getCases(from members: MemberDeclListSyntax) -> [EnumUnionCase] {
        return members.compactMap({ $0.decl.as(EnumCaseDeclSyntax.self) }).flatMap(getCases(from:))
    }

    private static func getCases(from caseDecl: EnumCaseDeclSyntax) -> [EnumUnionCase] {
        return caseDecl.elements.map(getCase(from:))
    }

    private static func getCase(from element: EnumCaseElementSyntax) -> EnumUnionCase {
        let values = (element.associatedValue?.parameterList).map(getAssociatedValues(from:)) ?? []
        return EnumUnionCase(
            caseIdentifierPattern: IdentifierPatternSyntax(identifier: element.identifier),
            associatedValues: values)
    }

    private static func getAssociatedValues(from list: EnumCaseParameterListSyntax) -> [AssociatedValue] {
        var values: [AssociatedValue] = []
        for (index, element) in list.enumerated() {
            let label: AssociatedValue.Label
            if let nameToken = element.firstName {
                label = .identifierPattern(IdentifierPatternSyntax(identifier: nameToken))
            } else {
                label = .index(index)
            }
            values.append(AssociatedValue(
                label: label,
                variableType: VariableHelper.getVariableType(from: element.type),
                isInitialized: element.defaultArgument != nil,
                firstNameToken: element.firstName))
        }
        return values
    }
}
