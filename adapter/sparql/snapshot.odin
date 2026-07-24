// Package sparql_adapter exposes a fixed reasoner closure as a SPARQL dataset.View.
package sparql_adapter

import "core:strings"
import rdf "odin-rdf:rdf"
import dataset "odin-sparql:sparql/dataset"
import store "../../reasoner/store"

// Options bounds an owned closure snapshot. A zero limit disables the bound.
Options :: struct { max_quads: int }

Error_Code :: enum { None, Invalid_Option, Quad_Limit, Out_Of_Memory, Store_Error }

error_message :: proc(code: Error_Code) -> string {
	switch code {
	case .None:           return "no error"
	case .Invalid_Option: return "snapshot limits must not be negative"
	case .Quad_Limit:     return "snapshot quad limit reached"
	case .Out_Of_Memory:  return "out of memory"
	case .Store_Error:    return "reasoner store could not yield a closure fact"
	}
	return "unknown SPARQL snapshot error"
}

// Snapshot owns an immutable default-graph copy of a reasoner closure. It may
// outlive the source Store; values delivered through view are borrowed until
// destroy. Named graph scans are explicitly unsupported and return Invalid_View.
Snapshot :: struct {
	quads: [dynamic]rdf.Quad,
	owned: [dynamic]string,
}

init :: proc(snapshot: ^Snapshot, source: ^store.Store, options: Options = {}) -> Error_Code {
	if options.max_quads < 0 do return .Invalid_Option
	snapshot^ = Snapshot{quads = make([dynamic]rdf.Quad), owned = make([dynamic]string)}
	for index in 0..<store.fact_count(source) {
		if options.max_quads != 0 && index >= options.max_quads { destroy(snapshot); return .Quad_Limit }
		id, _, _, found := store.fact_at(source, index)
		if !found { destroy(snapshot); return .Store_Error }
		triple, valid := store.triple_for(source, id)
		if !valid { destroy(snapshot); return .Store_Error }
		if error := append_quad(snapshot, rdf.default_graph_quad(triple)); error != .None { destroy(snapshot); return error }
	}
	return .None
}

destroy :: proc(snapshot: ^Snapshot) {
	for value in snapshot.owned do delete(value)
	delete(snapshot.owned)
	delete(snapshot.quads)
	snapshot^ = {}
}

quad_count :: proc(snapshot: ^Snapshot) -> int { return len(snapshot.quads) }

@(private) own_string :: proc(snapshot: ^Snapshot, value: string) -> (string, Error_Code) {
	if len(value) == 0 do return "", .None
	owned, clone_error := strings.clone(value)
	if clone_error != nil do return "", .Out_Of_Memory
	_, append_error := append(&snapshot.owned, owned)
	if append_error != nil { delete(owned); return "", .Out_Of_Memory }
	return owned, .None
}

@(private) own_term :: proc(snapshot: ^Snapshot, value: rdf.Term) -> (rdf.Term, Error_Code) {
	result := value
	error: Error_Code
	result.value, error = own_string(snapshot, value.value)
	if error != .None do return {}, error
	result.language, error = own_string(snapshot, value.language)
	if error != .None do return {}, error
	result.datatype, error = own_string(snapshot, value.datatype)
	if error != .None do return {}, error
	return result, .None
}

@(private) discard_owned_from :: proc(snapshot: ^Snapshot, start: int) {
	for index in start..<len(snapshot.owned) do delete(snapshot.owned[index])
	resize(&snapshot.owned, start)
}

@(private) append_quad :: proc(snapshot: ^Snapshot, value: rdf.Quad) -> Error_Code {
	owned_start := len(snapshot.owned)
	stored: rdf.Quad
	error: Error_Code
	stored.subject, error = own_term(snapshot, value.subject)
	if error != .None { discard_owned_from(snapshot, owned_start); return error }
	stored.predicate, error = own_term(snapshot, value.predicate)
	if error != .None { discard_owned_from(snapshot, owned_start); return error }
	stored.object, error = own_term(snapshot, value.object)
	if error != .None { discard_owned_from(snapshot, owned_start); return error }
	_, append_error := append(&snapshot.quads, stored)
	if append_error != nil { discard_owned_from(snapshot, owned_start); return .Out_Of_Memory }
	return .None
}

@(private) equal_term :: proc(left, right: rdf.Term) -> bool {
	return left.kind == right.kind && left.value == right.value && strings.equal_fold(left.language, right.language) && left.datatype == right.datatype && left.scope == right.scope
}

@(private) matches :: proc(pattern: dataset.Quad_Pattern, quad: rdf.Quad) -> bool {
	return (!pattern.Has_Subject || equal_term(pattern.Subject, quad.subject)) &&
		(!pattern.Has_Predicate || equal_term(pattern.Predicate, quad.predicate)) &&
		(!pattern.Has_Object || equal_term(pattern.Object, quad.object))
}

@(private) scan :: proc(data: rawptr, pattern: dataset.Quad_Pattern, sink: dataset.Scan_Sink, sink_data: rawptr) -> dataset.Error_Code {
	if pattern.Graph_Mode != .Default do return .Invalid_View
	snapshot := cast(^Snapshot)data
	for quad in snapshot.quads {
		if matches(pattern, quad) && !sink(quad, sink_data) do break
	}
	return .None
}

// view returns a borrowed dataset view for the immutable default graph only.
// Keep snapshot alive for every scan and SPARQL execution using this view.
view :: proc(snapshot: ^Snapshot) -> dataset.View {
	return dataset.custom_view(scan, snapshot)
}
