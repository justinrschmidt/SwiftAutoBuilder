import SwiftParser
import SwiftSyntax
import SwiftSyntaxBuilder
import XCTest
@testable import AutoBuilderMacros

final class SuperclassInspectorTests: XCTestCase {

    // MARK: - Has Superclass Argument

    func testHasSuperclassArgument_struct() throws {
        let structDecl = try StructDeclSyntax("@Buildable(superclassInitializer: Foo.init) struct Bar") {}
        XCTAssertTrue(SuperclassInspector.hasSuperclassArgument(in: structDecl.attributes))
    }

    func testHasSuperclassArgument_enum() throws {
        let enumDecl = try EnumDeclSyntax("@Buildable(superclassInitializer: Foo.init) enum Bar") {}
        XCTAssertTrue(SuperclassInspector.hasSuperclassArgument(in: enumDecl.attributes))
    }

    func testHasSuperclassArgument_class() throws {
        let classDecl = try ClassDeclSyntax("@Buildable(superclassInitializer: Foo.init) class Bar") {}
        XCTAssertTrue(SuperclassInspector.hasSuperclassArgument(in: classDecl.attributes))
    }

    func testDoesNotHaveSuperclassArgument_struct() throws {
        let structDecl = try StructDeclSyntax("@Buildable struct Bar") {}
        XCTAssertFalse(SuperclassInspector.hasSuperclassArgument(in: structDecl.attributes))
    }

    func testDoesNotHaveSuperclassArgument_enum() throws {
        let enumDecl = try EnumDeclSyntax("@Buildable enum Bar") {}
        XCTAssertFalse(SuperclassInspector.hasSuperclassArgument(in: enumDecl.attributes))
    }

    func testDoesNotHaveSuperclassArgument_class() throws {
        let classDecl = try ClassDeclSyntax("@Buildable class Bar") {}
        XCTAssertFalse(SuperclassInspector.hasSuperclassArgument(in: classDecl.attributes))
    }

    // MARK: - Get Superclass Initializer

    func testGetSuperclassInitializer_withArguments() throws {
        let classDecl = try ClassDeclSyntax("@Buildable<Foo, Int, Double>(superclassInitializer: Foo.init(a:_:)) class Bar") {}

        let initializer = SuperclassInspector.getSuperclassInitializer(from: classDecl)

        XCTAssertNotNil(initializer)

        XCTAssertNotNil(initializer?.genericArgumentTypes)
        let argumentTypes = initializer?.genericArgumentTypes
        XCTAssertEqual(argumentTypes?.count, 3)
        XCTAssertEqual(argumentTypes?[0].as(IdentifierTypeSyntax.self)?.name.tokenKind, .identifier("Foo"))
        XCTAssertEqual(argumentTypes?[1].as(IdentifierTypeSyntax.self)?.name.tokenKind, .identifier("Int"))
        XCTAssertEqual(argumentTypes?[2].as(IdentifierTypeSyntax.self)?.name.tokenKind, .identifier("Double"))

        XCTAssertNotNil(initializer?.initializerBase)
        XCTAssertEqual(
            initializer?.initializerBase?.as(DeclReferenceExprSyntax.self)?.baseName.tokenKind, .identifier("Foo"))

        XCTAssertNotNil(initializer?.initializerName)
        XCTAssertEqual(initializer?.initializerName!.tokenKind, .keyword(.`init`))

        XCTAssertNotNil(initializer?.parameterLabels)
        XCTAssertEqual(initializer?.parameterLabels?.count, 2)
        XCTAssertEqual(initializer?.parameterLabels?[0].tokenKind, .identifier("a"))
        XCTAssertEqual(initializer?.parameterLabels?[1].tokenKind, .wildcard)

        let params = initializer?.parameters
        XCTAssertNotNil(params)
        XCTAssertEqual(params?.count, 2)
        XCTAssertEqual(params?[0].label.tokenKind, .identifier("a"))
        XCTAssertEqual(params?[0].type.as(IdentifierTypeSyntax.self)?.name.tokenKind, .identifier("Int"))
        XCTAssertEqual(params?[1].label.tokenKind, .wildcard)
        XCTAssertEqual(params?[1].type.as(IdentifierTypeSyntax.self)?.name.tokenKind, .identifier("Double"))
    }

    func testGetSuperclassInitializer_noArguments() throws {
        let classDecl = try ClassDeclSyntax("@Buildable<Foo>(superclassInitializer: Foo.init) class Bar") {}

        let initializer = SuperclassInspector.getSuperclassInitializer(from: classDecl)

        XCTAssertNotNil(initializer)

        XCTAssertNotNil(initializer?.genericArgumentTypes)
        XCTAssertEqual(initializer?.genericArgumentTypes?.count, 1)
        XCTAssertEqual(
            initializer?.genericArgumentTypes?[0].as(IdentifierTypeSyntax.self)?.name.tokenKind, .identifier("Foo"))

        XCTAssertNotNil(initializer?.initializerBase)
        XCTAssertEqual(
            initializer?.initializerBase?.as(DeclReferenceExprSyntax.self)?.baseName.tokenKind, .identifier("Foo"))

        XCTAssertNotNil(initializer?.initializerName)
        XCTAssertEqual(initializer?.initializerName!.tokenKind, .keyword(.`init`))

        XCTAssertNil(initializer?.parameterLabels)

        XCTAssertNil(initializer?.parameters)
    }

    func testGetSuperclassInitializer_missingGenericArguments() throws {
        let classDecl = try ClassDeclSyntax("@Buildable(superclassInitializer: Foo.init) class Bar") {}

        let initializer = SuperclassInspector.getSuperclassInitializer(from: classDecl)

        XCTAssertNotNil(initializer)

        XCTAssertNil(initializer?.genericArgumentTypes)

        XCTAssertNotNil(initializer?.initializerBase)
        XCTAssertEqual(
            initializer?.initializerBase?.as(DeclReferenceExprSyntax.self)?.baseName.tokenKind, .identifier("Foo"))

        XCTAssertNotNil(initializer?.initializerName)
        XCTAssertEqual(initializer?.initializerName?.tokenKind, .keyword(.`init`))

        XCTAssertNil(initializer?.parameterLabels)

        XCTAssertNil(initializer?.parameters)
    }

    func testGetSuperclassInitializer_functionNotInit() throws {
        let classDecl = try ClassDeclSyntax("@Buildable<Foo>(superclassInitializer: Foo.baz) class Bar") {}

        let initializer = SuperclassInspector.getSuperclassInitializer(from: classDecl)

        XCTAssertNotNil(initializer)

        XCTAssertNotNil(initializer?.genericArgumentTypes)
        XCTAssertEqual(initializer?.genericArgumentTypes!.count, 1)
        XCTAssertEqual(
            initializer?.genericArgumentTypes?[0].as(IdentifierTypeSyntax.self)?.name.tokenKind, .identifier("Foo"))

        XCTAssertNotNil(initializer?.initializerBase)
        XCTAssertEqual(
            initializer?.initializerBase?.as(DeclReferenceExprSyntax.self)?.baseName.tokenKind, .identifier("Foo"))

        XCTAssertNotNil(initializer?.initializerName)
        XCTAssertEqual(initializer?.initializerName?.tokenKind, .identifier("baz"))

        XCTAssertNil(initializer?.parameterLabels)

        XCTAssertNil(initializer?.parameters)
    }

    func testGetSuperclassInitializer_withClosure() throws {
        let classDecl = try ClassDeclSyntax("@Buildable<Foo, Int, Double>(superclassInitializer: { (a, b) in return c }) class Bar") {}

        let initializer = SuperclassInspector.getSuperclassInitializer(from: classDecl)

        XCTAssertNil(initializer)
    }
}
