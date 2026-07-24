// Materialize the RDFS Core profile from a local Turtle document.
package main

import "core:fmt"
import "core:os"
import "core:strings"
import importer "../../reasoner/import"
import rdfs "../../reasoner/rdfs"
import rule "../../reasoner/rule"
import store "../../reasoner/store"
import ntriples "odin-rdf:rdf/ntriples"
import turtle "odin-rdf:rdf/turtle"

print_facts :: proc(target: ^store.Store, origin: store.Origin) {
	output := strings.builder_make()
	defer strings.builder_destroy(&output)
	for index in 0..<store.fact_count(target) {
		id, _, actual_origin, found := store.fact_at(target, index)
		if !found || actual_origin != origin do continue
		triple, valid := store.triple_for(target, id)
		if valid do _ = ntriples.write_triple(&output, triple)
	}
	fmt.print(strings.to_string(output))
}

main :: proc() {
	if len(os.args) != 2 {
		fmt.eprintln("usage: rdfs_materialize <input.ttl>")
		return
	}
	input, read_error := os.read_entire_file(os.args[1], context.allocator)
	if read_error != nil {
		fmt.eprintf("cannot read %s: %v\n", os.args[1], read_error)
		return
	}
	defer delete(input)

	target: store.Store
	if error := store.init(&target); error != .None { fmt.eprintln(store.error_message(error)); return }
	defer store.destroy(&target)
	state: importer.Sink_State
	importer.init(&state, &target)
	if parsed := turtle.parse(string(input), importer.triple_sink, {}, &state); parsed.code != .None {
		fmt.eprintln(turtle.parse_error_message(parsed.code), store.error_message(state.last_error))
		return
	}
	profile: rdfs.Profile
	if error, store_error := rdfs.init(&profile, &target); error != .None {
		fmt.eprintln(rdfs.error_message(error), store.error_message(store_error))
		return
	}
	defer rdfs.destroy(&profile)
	result := rdfs.materialize(&profile, &target)
	if result.error != .None { fmt.eprintln(rule.error_message(result.error)); return }

	fmt.println("# asserted")
	print_facts(&target, .Asserted)
	fmt.println("# inferred")
	print_facts(&target, .Inferred)
	if derivation, found := rule.derivation_at(&profile.materializer, 0); found {
		fmt.printf("# provenance: fact=%d rule=%d supports=%v\n", derivation.fact_id, derivation.rule_id, derivation.supports)
	}
}
