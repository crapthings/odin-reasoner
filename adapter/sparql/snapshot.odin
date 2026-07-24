// Package sparql_adapter exposes a fixed reasoner closure as a SPARQL dataset.View.
package sparql_adapter

import "core:strings"
import rdf "odin-rdf:rdf"
import dataset "odin-sparql:sparql/dataset"
import store "../../reasoner/store"
import term "../../reasoner/term"

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

Snapshot_Storage :: enum { Empty, Copied_Quads, Adopted_Store }

// Snapshot owns an immutable default-graph closure. init creates an independent
// copied snapshot; adopt_store transfers an already materialized Store without
// copying its terms, facts, or indexes. Values delivered through view are
// borrowed until destroy. Named graph scans are explicitly unsupported and
// return Invalid_View.
Snapshot :: struct {
	storage: Snapshot_Storage,
	quads: [dynamic]rdf.Quad,
	owned: [dynamic]string,
	adopted_store: store.Store,
}

init :: proc(snapshot: ^Snapshot, source: ^store.Store, options: Options = {}) -> Error_Code {
	if options.max_quads < 0 do return .Invalid_Option
	snapshot^ = Snapshot{storage = .Copied_Quads, quads = make([dynamic]rdf.Quad), owned = make([dynamic]string)}
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

// adopt_store transfers source into snapshot without a second RDF Dataset
// allocation. After it returns, source is reset and must not be used except
// for destroy. The caller must finish all Store mutation and materialization
// before adoption; view exposes only read-only scans over the adopted Store.
adopt_store :: proc(snapshot: ^Snapshot, source: ^store.Store) {
	snapshot^ = Snapshot{storage = .Adopted_Store, adopted_store = source^}
	source^ = {}
}

destroy :: proc(snapshot: ^Snapshot) {
	switch snapshot.storage {
	case .Copied_Quads:
		for value in snapshot.owned do delete(value)
		delete(snapshot.owned)
		delete(snapshot.quads)
	case .Adopted_Store:
		store.destroy(&snapshot.adopted_store)
	case .Empty:
	}
	snapshot^ = {}
}

quad_count :: proc(snapshot: ^Snapshot) -> int {
	if snapshot.storage == .Adopted_Store do return store.fact_count(&snapshot.adopted_store)
	return len(snapshot.quads)
}

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

@(private) snapshot_scan :: proc(data: rawptr, pattern: dataset.Quad_Pattern, sink: dataset.Scan_Sink, sink_data: rawptr) -> dataset.Error_Code {
	if pattern.Graph_Mode != .Default do return .Invalid_View
	snapshot := cast(^Snapshot)data
	if snapshot.storage == .Adopted_Store do return indexed_scan(&snapshot.adopted_store, pattern, sink, sink_data)
	for quad in snapshot.quads {
		if matches(pattern, quad) && !sink(quad, sink_data) do break
	}
	return .None
}

// view returns a borrowed dataset view for the immutable default graph only.
// Keep snapshot alive for every scan and SPARQL execution using this view.
view :: proc(snapshot: ^Snapshot) -> dataset.View {
	return dataset.custom_view(snapshot_scan, snapshot)
}

// indexed_view exposes a borrowed, default-graph View directly over a live
// reasoner Store. It reuses the Store's owned RDF terms and indexed match
// operation, so it does not allocate a second closure dataset. The caller must
// keep source alive and must not mutate it during a scan or query execution.
// Use Snapshot when the View must outlive source or require an owned immutable
// copy.
indexed_view :: proc(source: ^store.Store) -> dataset.View {
	return dataset.custom_view(indexed_scan, source)
}

@(private) Indexed_Scan_State :: struct {
	source:    ^store.Store,
	sink:      dataset.Scan_Sink,
	sink_data: rawptr,
	invalid:   bool,
}

@(private) indexed_scan_sink :: proc(id: store.Fact_ID, _: store.Fact, _: store.Origin, user_data: rawptr) -> bool {
	state := cast(^Indexed_Scan_State)user_data
	triple, found := store.triple_for(state.source, id)
	if !found {
		state.invalid = true
		return false
	}
	return state.sink(rdf.default_graph_quad(triple), state.sink_data)
}

@(private) indexed_scan :: proc(data: rawptr, pattern: dataset.Quad_Pattern, sink: dataset.Scan_Sink, sink_data: rawptr) -> dataset.Error_Code {
	if pattern.Graph_Mode != .Default do return .Invalid_View
	source := cast(^store.Store)data
	store_pattern: store.Pattern
	if pattern.Has_Subject {
		id := store.id_for_term(source, pattern.Subject)
		if id == term.INVALID_TERM_ID do return .None
		store_pattern.subject = id
	}
	if pattern.Has_Predicate {
		id := store.id_for_term(source, pattern.Predicate)
		if id == term.INVALID_TERM_ID do return .None
		store_pattern.predicate = id
	}
	if pattern.Has_Object {
		id := store.id_for_term(source, pattern.Object)
		if id == term.INVALID_TERM_ID do return .None
		store_pattern.object = id
	}
	state := Indexed_Scan_State{source = source, sink = sink, sink_data = sink_data}
	result := store.match(source, store_pattern, indexed_scan_sink, &state)
	if state.invalid || result.error != store.Error_Code.None do return .Invalid_View
	return .None
}
