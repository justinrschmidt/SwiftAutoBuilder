import SwiftSyntax
import SwiftSyntaxBuilder

struct VariableHelper {
    static func getStoredProperties(from members: MemberDeclListSyntax) -> [Property] {
        let variables: [VariableDeclSyntax] = members.compactMap({ member in
            guard let variable = member.decl.as(VariableDeclSyntax.self) else { return nil }
            return isStoredProperty(variable) ? variable : nil
        })
        return variables.flatMap(getProperties(from:))
    }

    private static func getProperties(from variable: VariableDeclSyntax) -> [Property] {
        guard let bindingKeyword = Property.BindingKeyword(kind: variable.bindingKeyword.tokenKind) else {
            return []
        }
        var typeNode: TypeSyntax?
        var properties: [Property] = []
        for patternBinding in variable.bindings.reversed() {
            if let identifierPattern = patternBinding.pattern.as(IdentifierPatternSyntax.self) {
                if patternBinding.initializer != nil {
                    typeNode = nil
                }
                if let type = patternBinding.typeAnnotation?.type {
                    typeNode = type
                }
                if let typeNode = typeNode {
                    properties.append(Property(
                        bindingKeyword: bindingKeyword,
                        identifierPattern: identifierPattern,
                        type: .explicit(typeNode: typeNode)))
                } else {
                    properties.append(Property(
                        bindingKeyword: bindingKeyword,
                        identifierPattern: identifierPattern,
                        type: .implicit))
                }
            }
            if let tuplePattern = patternBinding.pattern.as(TuplePatternSyntax.self) {
                typeNode = nil
                if let typeAnnotation = patternBinding.typeAnnotation {
                    properties += getProperties(
                        from: tuplePattern,
                        type: typeAnnotation.type.cast(TupleTypeSyntax.self),
                        bindingKeyword: bindingKeyword
                    ).reversed()
                } else {
                    for identifierPattern in getTupleIdentifiers(from: tuplePattern).reversed() {
                        properties.append(Property(
                            bindingKeyword: bindingKeyword,
                            identifierPattern: identifierPattern,
                            type: .implicit))
                    }
                }
            }
        }
        return properties.reversed()
    }

    private static func getProperties(from tuplePattern: TuplePatternSyntax, type: TupleTypeSyntax, bindingKeyword: Property.BindingKeyword) -> [Property] {
        var properties: [Property] = []
        var patternIterator = tuplePattern.elements.makeIterator()
        var typeIterator = type.elements.makeIterator()
        while let patternElement = patternIterator.next(),
              let typeElement = typeIterator.next() {
            if let identifierPattern = patternElement.pattern.as(IdentifierPatternSyntax.self) {
                properties.append(Property(
                    bindingKeyword: bindingKeyword,
                    identifierPattern: identifierPattern,
                    type: .explicit(typeNode: typeElement.type.cast(TypeSyntax.self))))
            } else if let subTuplePattern = patternElement.pattern.as(TuplePatternSyntax.self),
                      let subTupleType = typeElement.type.as(TupleTypeSyntax.self) {
                properties += getProperties(from: subTuplePattern, type: subTupleType, bindingKeyword: bindingKeyword)
            }
        }
        return properties
    }

    private static func getTupleIdentifiers(from tuplePattern: TuplePatternSyntax) -> [IdentifierPatternSyntax] {
        var identifiers: [IdentifierPatternSyntax] = []
        for element in tuplePattern.elements {
            if let identifierPattern = element.pattern.as(IdentifierPatternSyntax.self) {
                identifiers.append(identifierPattern)
            } else if let subTuplePattern = element.pattern.as(TuplePatternSyntax.self) {
                identifiers += getTupleIdentifiers(from: subTuplePattern)
            }
        }
        return identifiers
    }

    static func isStoredProperty(_ variable: VariableDeclSyntax) -> Bool {
        switch variable.bindingKeyword.tokenKind {
        case TokenKind.keyword(.let):
            return true
        case TokenKind.keyword(.var):
            let bindings = variable.bindings
            return !hasCodeBlockSyntaxAccessor(bindings) && !hasGetOrSetAccessorInAccessorBlockSyntax(bindings)
        default:
            return false
        }
    }

    private static func hasCodeBlockSyntaxAccessor(_ bindings: PatternBindingListSyntax) -> Bool {
        return bindings.contains(where: { $0.accessor?.is(CodeBlockSyntax.self) ?? false })
    }

    private static func hasGetOrSetAccessorInAccessorBlockSyntax(_ bindings: PatternBindingListSyntax) -> Bool {
        return bindings.contains(where: { binding in
            binding.accessor?.as(AccessorBlockSyntax.self).map({ hasGetOrSetAccessor($0.accessors) }) ?? false
        })
    }

    private static let getSetTokens: Set<TokenKind> = [TokenKind.keyword(.get), TokenKind.keyword(.set)]

    private static func hasGetOrSetAccessor(_ accessors: AccessorListSyntax) -> Bool {
        return accessors.contains(where: { getSetTokens.contains($0.accessorKind.tokenKind) })
    }
}
