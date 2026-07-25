// Package importer adapts transient RDF parser callbacks to the owned store.
package importer

import rdf "odin-rdf:rdf"
import store "../store"

// Sink_State owns no RDF data. The parser callback updates last_error after
// every attempted insertion; a false return asks the parser to stop.
Sink_State :: struct {
	target:     ^store.Store,
	origin:     store.Origin,
	last_error: store.Error_Code,
	inserted:   int,
	duplicates: int,
	rejected_named_graph: bool,
}

init :: proc(state: ^Sink_State, target: ^store.Store, origin: store.Origin = .Asserted) {
	state^ = Sink_State{target = target, origin = origin}
}

// triple_sink is suitable for any odin-rdf triple parser. It immediately
// interns every callback term through store.insert_triple and never retains
// parser-borrowed strings in Sink_State.
triple_sink :: proc(triple: rdf.Triple, user_data: rawptr) -> bool {
	state := cast(^Sink_State)user_data
	if state == nil || state.target == nil do return false
	added, error := store.insert_triple(state.target, triple, state.origin)
	state.last_error = error
	if error != .None do return false
	if added {
		state.inserted += 1
	} else {
		state.duplicates += 1
	}
	return true
}

// quad_sink adapts parsers such as RDF/XML that publish default-graph quads.
// The reasoner store is a single RDF graph, so named graph statements are
// rejected explicitly instead of being silently flattened into asserted data.
quad_sink :: proc(quad: rdf.Quad, user_data: rawptr) -> bool {
	state := cast(^Sink_State)user_data
	if state == nil || state.target == nil do return false
	if quad.has_graph {
		state.rejected_named_graph = true
		return false
	}
	return triple_sink(rdf.triple(quad), user_data)
}
