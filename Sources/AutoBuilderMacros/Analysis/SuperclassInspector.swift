import SwiftSyntax
import SwiftSyntaxBuilder

/// Contains methods relating to analyzing the `Buildable` attribute for a superclass initializer and extracting the
/// declarations relating to the superclass's initializer.
struct SuperclassInspector {

    /// Checks if the given attribute list contains a `Buildable` attribute and if that attribute has the
    /// `superclassInitializer` parameter.
    /// - Parameters:
    ///   - attributeList: The attribute list to check.
    /// - Returns: `true` if the attribute list contains a `Buildable` attribute with the `superclassInitializer`
    /// parameter, `false` otherwise.
    static func hasSuperclassArgument(in attributeList: AttributeListSyntax) -> Bool {
        guard let buildableAttribute = getBuildableAttribute(in: attributeList) else { return false }
        return getSuperclassInitializerExpr(in: buildableAttribute) != nil
    }

    /// Returns a `SuperclassInitializer` that contains the declarations relating to a superclass's initializer.
    /// - Parameters:
    ///   - decl: The class declaration that has the `Buildable` attribute with a `superclassInitializer` for the
    ///   superclass's initializer declarations.
    /// - Returns: A `SuperclassInitializer` populated with the superclass's initalizer declarations, if it exists,
    /// `nil` if no superclass initalizer declaration is found.
    static func getSuperclassInitializer(from decl: ClassDeclSyntax) -> SuperclassInitializer? {
        guard let buildableAttribute = getBuildableAttribute(in: decl.attributes) else { return nil }
        guard let attributeName = buildableAttribute.attributeName.as(IdentifierTypeSyntax.self) else { return nil }
        guard let initExpr = getSuperclassInitializerExpr(in: buildableAttribute) else { return nil }
        let argumentTypes = attributeName.genericArgumentClause?.arguments.map({ $0.argument })
        let parameterLabels = initExpr.declName.argumentNames?.arguments.map({ $0.name })
        let parameters: [SuperclassInitializer.Parameter]?
        if let types = argumentTypes?.dropFirst(), let labels = parameterLabels, types.count == labels.count {
            parameters = zip(labels, types).map({ SuperclassInitializer.Parameter(label: $0, type: $1) })
        } else {
            parameters = nil
        }
        return SuperclassInitializer(
            buildableAttribute: buildableAttribute,
            genericArgumentTypes: argumentTypes,
            initializerBase: initExpr.base,
            initializerName: initExpr.declName.baseName,
            parameterLabels: parameterLabels,
            parameters: parameters)
    }

    /// Returns the `AttributeSyntax` of the `Buildable` attribute in the given attribute list, if it exists.
    /// - Parameters:
    ///   - attributeList: The list of attributes to search through for the `Buildable` attribute.
    /// - Returns: The `Buildable` attribute, if it exists in the list, `nil` otherwise.
    static func getBuildableAttribute(in attributeList: AttributeListSyntax) -> AttributeSyntax? {
        for listElement in attributeList {
            guard case let .attribute(attributeSyntax) = listElement else { continue }
            guard let identifier = attributeSyntax.attributeName.as(IdentifierTypeSyntax.self) else { continue }
            if identifier.name.text == "Buildable" {
                return attributeSyntax
            }
        }
        return nil
    }

    private static func getSuperclassInitializerExpr(in attribute: AttributeSyntax) -> MemberAccessExprSyntax? {
        guard case let .argumentList(arguments) = attribute.arguments else { return nil }
        for labeledExpr in arguments {
            guard labeledExpr.label?.text == "superclassInitializer" else { continue }
            guard let expression = labeledExpr.expression.as(MemberAccessExprSyntax.self) else { continue }
            return expression
        }
        return nil
    }

    /// Contains the declarations in a `Buildable` attribute for a superclass's initializer.
    struct SuperclassInitializer {

        let buildableAttribute: AttributeSyntax

        /// The list of generic arguments for the attribute.
        let genericArgumentTypes: [TypeSyntax]?

        /// The base expression for the initializer. Appears on the left side of the `.`. Typically, this is the
        /// superclass's name.
        let initializerBase: ExprSyntax?

        /// The function base name of the initializer. Appears on the left side of the `.` and left of the `(`.
        /// Typically, this is `init`.
        let initializerName: TokenSyntax?

        /// The parameter labels used in the initializer. Includes wildcards for parameters that do not have labels.
        let parameterLabels: [TokenSyntax]?

        /// The parameters for the initializer.
        let parameters: [Parameter]?

        /// A parameter in a function.
        struct Parameter {

            /// The parameter's label.
            let label: TokenSyntax

            /// The parameter's type.
            let type: TypeSyntax
        }
    }
}
