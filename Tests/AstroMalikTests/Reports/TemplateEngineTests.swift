import XCTest
@testable import AstroMalik

final class Reports: XCTestCase {}

extension Reports {
    func testTemplateEngineRendersSimpleDotVariable() throws {
        let engine = TemplateEngine()
        let html = try engine.render(
            template: "Hola {{user.name}}",
            context: ["user": ["name": "Malik"]]
        )
        XCTAssertEqual(html, "Hola Malik")
    }

    func testTemplateEngineEscapesHTMLByDefault() throws {
        let engine = TemplateEngine()
        let html = try engine.render(
            template: "{{value}}",
            context: ["value": "<Sol & Luna \"x\" 'y'>"]
        )
        XCTAssertEqual(html, "&lt;Sol &amp; Luna &quot;x&quot; &#39;y&#39;&gt;")
    }

    func testTemplateEngineRendersTripleMustacheWithoutEscaping() throws {
        let engine = TemplateEngine()
        let html = try engine.render(
            template: "{{{raw}}}",
            context: ["raw": "<strong>Sol</strong>"]
        )
        XCTAssertEqual(html, "<strong>Sol</strong>")
    }

    func testTemplateEngineRendersEachLoop() throws {
        let engine = TemplateEngine()
        let html = try engine.render(
            template: "{{#each items}}<li>{{name}}:{{value}}</li>{{/each}}",
            context: [
                "items": [
                    ["name": "Sol", "value": 10],
                    ["name": "Luna", "value": 20],
                ]
            ]
        )
        XCTAssertEqual(html, "<li>Sol:10</li><li>Luna:20</li>")
    }

    func testTemplateEngineRendersIfAndUnlessSections() throws {
        let engine = TemplateEngine()
        let html = try engine.render(
            template: "{{#if visible}}Sí{{/if}}{{#unless hidden}} No{{/unless}}",
            context: ["visible": true, "hidden": false]
        )
        XCTAssertEqual(html, "Sí No")
    }

    func testTemplateEngineIncludesPartialsViaLoader() throws {
        let engine = TemplateEngine { name in
            guard name == "row" else { throw TemplateError.missingPartial(name: name) }
            return "<span>{{item}}</span>"
        }
        let html = try engine.render(
            template: "Antes {{> row}} Después",
            context: ["item": "Marte"]
        )
        XCTAssertEqual(html, "Antes <span>Marte</span> Después")
    }

    func testTemplateEngineThrowsUnknownVariable() throws {
        let engine = TemplateEngine()
        XCTAssertThrowsError(try engine.render(template: "{{missing}}", context: [:])) { error in
            XCTAssertEqual(error as? TemplateError, .unknownVariable("missing"))
        }
    }

    func testTemplateEngineThrowsMalformedSyntaxAndMissingPartial() throws {
        let engine = TemplateEngine()
        XCTAssertThrowsError(try engine.render(template: "A\n{{#if enabled}}sin cierre", context: ["enabled": true])) { error in
            guard case TemplateError.malformedSyntax(let line) = error else {
                return XCTFail("Error inesperado: \(error)")
            }
            XCTAssertEqual(line, 2)
        }

        XCTAssertThrowsError(try engine.render(template: "{{> unknown}}", context: [:])) { error in
            XCTAssertEqual(error as? TemplateError, .missingPartial(name: "unknown"))
        }
    }
}
