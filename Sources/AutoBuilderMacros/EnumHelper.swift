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
        let properties = (element.associatedValue?.parameterList).map(getProperties(from:)) ?? []
        return EnumUnionCase(
            caseIdentifierPattern: IdentifierPatternSyntax(identifier: element.identifier),
            associatedValues: properties)
    }

    private static func getProperties(from list: EnumCaseParameterListSyntax) -> [Property] {
        var properties: [Property] = []
        for element in list {
            let nameToken = element.firstName ?? .identifier("")
            properties.append(Property(
                isStoredProperty: true,
                isIVar: true,
                bindingKeyword: .var,
                identifierPattern: IdentifierPatternSyntax(identifier: nameToken),
                type: VariableHelper.getVariableType(from: element.type),
                isInitialized: element.defaultArgument != nil))
        }
        return properties
    }
}
