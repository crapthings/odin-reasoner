// This program demonstrates that emitted RDF parser values are safely owned by
// the reasoner store after parsing returns.
package main

import "core:fmt"
import "core:strings"
import importer "../../reasoner/import"
import store "../../reasoner/store"
import ntriples "odin-rdf:rdf/ntriples"
import turtle "odin-rdf:rdf/turtle"

main :: proc() {
	target: store.Store
	if error := store.init(&target, {max_terms = 64, max_facts = 32}); error != .None {
		fmt.eprintln(store.error_message(error))
		return
	}
	defer store.destroy(&target)

	state: importer.Sink_State
	importer.init(&state, &target)
	input := `@prefix ex: <https://example.test/> .
ex:alice ex:knows _:friend .
_:friend ex:name "Bob"@en .`
	if parsed := turtle.parse(input, importer.triple_sink, {}, &state); parsed.code != .None {
		fmt.eprintln(turtle.parse_error_message(parsed.code), store.error_message(state.last_error))
		return
	}

	output := strings.builder_make()
	defer strings.builder_destroy(&output)
	for index in 0..<store.fact_count(&target) {
		id, _, _, found := store.fact_at(&target, index)
		if !found do continue
		triple, valid := store.triple_for(&target, id)
		if !valid || ntriples.write_triple(&output, triple) != .None do return
	}
	fmt.print(strings.to_string(output))
}
