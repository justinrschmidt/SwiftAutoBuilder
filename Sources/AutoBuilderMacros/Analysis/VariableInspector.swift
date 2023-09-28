import SwiftSyntax
import SwiftSyntaxBuilder

struct VariableInspector {
    static func getProperties(from members: MemberBlockItemListSyntax) -> [Property] {
        let variables: [VariableDeclSyntax] = members.compactMap({ $0.decl.as(VariableDeclSyntax.self) })
        return variables.flatMap(getProperties(from:))
    }

    private static func getProperties(from variable: VariableDeclSyntax) -> [Property] {
        guard let bindingKeyword = Property.BindingKeyword(kind: variable.bindingSpecifier.tokenKind) else {
            return []
        }
        let isStored = isStoredProperty(variable)
        let isIVar = !isStatic(variable)
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
                properties.append(Property(
                    isStoredProperty: isStored,
                    isIVar: isIVar,
                    bindingKeyword: bindingKeyword,
                    identifierPattern: identifierPattern,
                    type: getVariableType(from: typeNode),
                    isInitialized: patternBinding.initializer != nil))
            }
            if let tuplePattern = patternBinding.pattern.as(TuplePatternSyntax.self) {
                typeNode = nil
                if let typeAnnotation = patternBinding.typeAnnotation {
                    properties += getProperties(
                        from: tuplePattern,
                        type: typeAnnotation.type.cast(TupleTypeSyntax.self),
                        isStored: isStored,
                        isIVar: isIVar,
                        bindingKeyword: bindingKeyword,
                        isInitialized: patternBinding.initializer != nil
                    ).reversed()
                } else {
                    for identifierPattern in getTupleIdentifiers(from: tuplePattern).reversed() {
                        properties.append(Property(
                            isStoredProperty: isStored,
                            isIVar: isIVar,
                            bindingKeyword: bindingKeyword,
                            identifierPattern: identifierPattern,
                            type: .implicit,
                            isInitialized: patternBinding.initializer != nil))
                    }
                }
            }
        }
        return properties.reversed()
    }

    private static func isStatic(_ variable: VariableDeclSyntax) -> Bool {
        variable.modifiers.contains(where: { modifier in
            modifier.name.tokenKind == .keyword(.static) || modifier.name.tokenKind == .keyword(.class)
        })
    }

    private static func getProperties(from tuplePattern: TuplePatternSyntax, type: TupleTypeSyntax, isStored: Bool, isIVar: Bool, bindingKeyword: Property.BindingKeyword, isInitialized: Bool) -> [Property] {
        var properties: [Property] = []
        var patternIterator = tuplePattern.elements.makeIterator()
        var typeIterator = type.elements.makeIterator()
        while let patternElement = patternIterator.next(),
              let typeElement = typeIterator.next() {
            if let identifierPattern = patternElement.pattern.as(IdentifierPatternSyntax.self) {
                properties.append(Property(
                    isStoredProperty: isStored,
                    isIVar: isIVar,
                    bindingKeyword: bindingKeyword,
                    identifierPattern: identifierPattern,
                    type: getVariableType(from: typeElement.type),
                    isInitialized: isInitialized))
            } else if let subTuplePattern = patternElement.pattern.as(TuplePatternSyntax.self),
                      let subTupleType = typeElement.type.as(TupleTypeSyntax.self) {
                properties += getProperties(from: subTuplePattern, type: subTupleType, isStored: isStored, isIVar: isIVar, bindingKeyword: bindingKeyword, isInitialized: isInitialized)
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

    static func getVariableType(from typeSyntax: TypeSyntax?) -> VariableType {
        guard let typeSyntax = typeSyntax else {
            return .implicit
        }
        if let arraySyntax = typeSyntax.as(ArrayTypeSyntax.self) {
            return .array(elementType: arraySyntax.element)
        } else if let dictionarySyntax = typeSyntax.as(DictionaryTypeSyntax.self) {
            return .dictionary(keyType: dictionarySyntax.key, valueType: dictionarySyntax.value)
        } else if let simpleTypeSyntax = typeSyntax.as(IdentifierTypeSyntax.self),
                  let genericClause = simpleTypeSyntax.genericArgumentClause {
            switch simpleTypeSyntax.name.text {
            case "Array":
                return .array(elementType: genericClause.arguments.first!.argument)
            case "Dictionary":
                var arguments = genericClause.arguments.makeIterator()
                let keyType = arguments.next()!.argument
                let valueType = arguments.next()!.argument
                return .dictionary(keyType: keyType, valueType: valueType)
            case "Set":
                return .set(elementType: genericClause.arguments.first!.argument)
            default:
                return .explicit(typeNode: typeSyntax)
            }
        } else {
            return .explicit(typeNode: typeSyntax)
        }
    }

    static func isStoredProperty(_ variable: VariableDeclSyntax) -> Bool {
        switch variable.bindingSpecifier.tokenKind {
        case TokenKind.keyword(.let):
            return true
        case TokenKind.keyword(.var):
            return !hasGetOrSetAccessor(variable.bindings)
        default:
            return false
        }
    }

    private static func hasGetOrSetAccessor(_ bindings: PatternBindingListSyntax) -> Bool {
        return bindings.contains(where: {
            switch $0.accessorBlock?.accessors {
            case let .accessors(accessorList):
                return accessorList.contains(where: { $0.accessorSpecifier.tokenKind == .keyword(.get) || $0.accessorSpecifier.tokenKind == .keyword(.set) })
            case .getter(_):
                return true
            case .none:
                return false
            }
        })
    }
}
