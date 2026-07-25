package importer

import "core:strings"
import rdf "odin-rdf:rdf"
import rdfxml "odin-rdf:rdf/rdfxml"
import store "../store"

// Import_Resolver supplies one RDF/XML document for an absolute owl:imports
// IRI. Transport, caching, authentication, and persistence remain caller-owned.
Import_Resolver :: proc(iri: string, user_data: rawptr) -> (document: string, found: bool)

// Import_Options bounds one closure load. root_iri is optional, but callers
// should provide the absolute identifier of root_document when it is known so
// an owl:imports self-cycle does not reparse the root.
Import_Options :: struct {
	max_documents: int,
	root_iri:      string,
}

Import_Error_Code :: enum {
	None,
	Missing_Resolver,
	Missing_Import,
	Import_Limit,
	RDFXML_Error,
	Store_Error,
	Named_Graph,
	Out_Of_Memory,
}

Import_Result :: struct {
	error:       Import_Error_Code,
	rdfxml_error: rdfxml.Parse_Error,
	store_error:  store.Error_Code,
	documents:    int,
}

@(private) Document_State :: struct {
	sink:        Sink_State,
	imports:     [dynamic]string,
	imports_iri: string,
	allocation_failed: bool,
}

@(private) destroy_document_state :: proc(state: ^Document_State) {
	for iri in state.imports do delete(iri)
	delete(state.imports)
}

@(private) import_quad_sink :: proc(quad: rdf.Quad, user_data: rawptr) -> bool {
	state := cast(^Document_State)user_data
	if state == nil do return false
	if !quad_sink(quad, &state.sink) do return false
	if quad.predicate.value != state.imports_iri || quad.predicate.kind != .IRI || quad.object.kind != .IRI do return true
	iri, clone_error := strings.clone(quad.object.value)
	if clone_error != nil {
		state.allocation_failed = true
		return false
	}
	_, append_error := append(&state.imports, iri)
	if append_error != nil {
		delete(iri)
		state.allocation_failed = true
		return false
	}
	return true
}

@(private) load_document :: proc(document: string, target: ^store.Store, resolver: Import_Resolver, resolver_data: rawptr, options: Import_Options, seen: ^map[string]bool, result: ^Import_Result) -> bool {
	if options.max_documents > 0 && result.documents >= options.max_documents {
		result.error = .Import_Limit
		return false
	}
	state: Document_State
	init(&state.sink, target)
	state.imports_iri = "http://www.w3.org/2002/07/owl#imports"
	parse_error := rdfxml.parse(document, import_quad_sink, {}, &state)
	if parse_error.code != .None {
		result.rdfxml_error = parse_error
		if state.allocation_failed {
			result.error = .Out_Of_Memory
		} else if state.sink.rejected_named_graph {
			result.error = .Named_Graph
		} else if state.sink.last_error != .None {
			result.error, result.store_error = .Store_Error, state.sink.last_error
		} else {
			result.error = .RDFXML_Error
		}
		destroy_document_state(&state)
		return false
	}
	if state.allocation_failed {
		result.error = .Out_Of_Memory
		destroy_document_state(&state)
		return false
	}
	if state.sink.rejected_named_graph {
		result.error = .Named_Graph
		destroy_document_state(&state)
		return false
	}
	if state.sink.last_error != .None {
		result.error, result.store_error = .Store_Error, state.sink.last_error
		destroy_document_state(&state)
		return false
	}
	result.documents += 1
	for iri in state.imports {
		if seen^[iri] do continue
		seen^[iri] = true
		if options.max_documents > 0 && result.documents >= options.max_documents {
			result.error = .Import_Limit
			destroy_document_state(&state)
			return false
		}
		if resolver == nil {
			result.error = .Missing_Resolver
			destroy_document_state(&state)
			return false
		}
		imported, found := resolver(iri, resolver_data)
		if !found {
			result.error = .Missing_Import
			destroy_document_state(&state)
			return false
		}
		if !load_document(imported, target, resolver, resolver_data, options, seen, result) {
			destroy_document_state(&state)
			return false
		}
	}
	destroy_document_state(&state)
	return true
}

// load_rdfxml_import_closure parses one root RDF/XML document and recursively
// resolves every reachable owl:imports IRI. Each resolved import IRI is parsed
// at most once.
// It loads into a private clone and replaces target only after the full closure
// succeeds, so every reported failure leaves target unchanged.
load_rdfxml_import_closure :: proc(root_document: string, target: ^store.Store, resolver: Import_Resolver = nil, options: Import_Options = {}, resolver_data: rawptr = nil) -> Import_Result {
	result: Import_Result
	if target == nil {
		result.error, result.store_error = .Store_Error, .Invalid_Fact
		return result
	}
	work: store.Store
	if clone_error := store.clone(target, &work); clone_error != .None {
		result.error, result.store_error = .Store_Error, clone_error
		return result
	}
	defer store.destroy(&work)
	seen := make(map[string]bool)
	defer delete(seen)
	if len(options.root_iri) != 0 do seen[options.root_iri] = true
	_ = load_document(root_document, &work, resolver, resolver_data, options, &seen, &result)
	if result.error == .None {
		store.destroy(target)
		target^ = work
		work = {}
	}
	return result
}
