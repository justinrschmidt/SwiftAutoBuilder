import SwiftDiagnostics
import SwiftParser
import SwiftSyntax
import SwiftSyntaxBuilder
import XCTest
@testable import AutoBuilderMacros

final class AutoBuilderDiagnosticTests: XCTestCase {
    func testCreateNonClassWithSuperclassInitializerDiagnostic_struct() throws {
        let structDecl = try StructDeclSyntax("@Buildable<Foo>(superclassInitializer: Foo.init) struct Bar") {}

        let diagnostic = AutoBuilderDiagnostic.createNonClassWithSuperclassInitialzierDiagnostic(
            from: structDecl.attributes)

        let buildableAttribute = structDecl.attributes.first!
        XCTAssertEqual(diagnostic.node, buildableAttribute.cast(AttributeSyntax.self).arguments!.cast(LabeledExprListSyntax.self).first!.cast(Syntax.self))
        XCTAssertEqual(diagnostic.message, AutoBuilderDiagnostic.nonClassWithSuperclassInitializer.message)
        XCTAssertEqual(diagnostic.fixIts.count, 1)
        XCTAssertEqual(diagnostic.fixIts[0].message as? AutoBuilderFixIt, .removeSuperclassInitializer)
        XCTAssertEqual(diagnostic.fixIts[0].changes.count, 1)
        let change = diagnostic.fixIts[0].changes[0]
        guard case let .replace(oldNode, newNode) = change else {
            XCTFail("The FixIt change type must be .replace")
            return
        }
        XCTAssertEqual(oldNode, buildableAttribute.cast(Syntax.self))
        XCTAssertNotNil(newNode.as(AttributeSyntax.self))
        XCTAssertNotNil(newNode.cast(AttributeSyntax.self).attributeName.as(IdentifierTypeSyntax.self))
        let attributeNameIdentifier = newNode.cast(AttributeSyntax.self).attributeName.cast(IdentifierTypeSyntax.self)
        XCTAssertEqual(attributeNameIdentifier.name.tokenKind, .identifier("Buildable"))
    }

    func testCreateNonClassWithSuperclassInitializerDiagnostic_enum() throws {
        let enumDecl = try EnumDeclSyntax("@Buildable<Foo>(superclassInitializer: Foo.init) enum Bar") {}

        let diagnostic = AutoBuilderDiagnostic.createNonClassWithSuperclassInitialzierDiagnostic(
            from: enumDecl.attributes)

        let buildableAttribute = enumDecl.attributes.first!
        XCTAssertEqual(diagnostic.node, buildableAttribute.cast(AttributeSyntax.self).arguments!.cast(LabeledExprListSyntax.self).first!.cast(Syntax.self))
        XCTAssertEqual(diagnostic.message, AutoBuilderDiagnostic.nonClassWithSuperclassInitializer.message)
        XCTAssertEqual(diagnostic.fixIts.count, 1)
        XCTAssertEqual(diagnostic.fixIts[0].message as? AutoBuilderFixIt, .removeSuperclassInitializer)
        XCTAssertEqual(diagnostic.fixIts[0].changes.count, 1)
        let change = diagnostic.fixIts[0].changes[0]
        guard case let .replace(oldNode, newNode) = change else {
            XCTFail("The FixIt change type must be .replace")
            return
        }
        XCTAssertEqual(oldNode, buildableAttribute.cast(Syntax.self))
        XCTAssertNotNil(newNode.as(AttributeSyntax.self))
        XCTAssertNotNil(newNode.cast(AttributeSyntax.self).attributeName.as(IdentifierTypeSyntax.self))
        let attributeNameIdentifier = newNode.cast(AttributeSyntax.self).attributeName.cast(IdentifierTypeSyntax.self)
        XCTAssertEqual(attributeNameIdentifier.name.tokenKind, .identifier("Buildable"))
    }
}
