package sparql_adapter

import "core:testing"
import rdf "odin-rdf:rdf"
import rdfs "../../reasoner/rdfs"
import rule "../../reasoner/rule"
import store "../../reasoner/store"
import sparql "odin-sparql:sparql"
import dataset "odin-sparql:sparql/dataset"
import engine "odin-sparql:sparql/engine"

@(private) add :: proc(t: ^testing.T, target: ^store.Store, triple: rdf.Triple) {
	added, error := store.insert_triple(target, triple)
	testing.expect(t, added)
	testing.expect_value(t, error, store.Error_Code.None)
}

@(private) run :: proc(t: ^testing.T, text: string, view: dataset.View) -> engine.Result {
	query, parse_error := sparql.Parse(text)
	defer sparql.Destroy(&query)
	testing.expect_value(t, sparql.Parse_Error_Code(parse_error), sparql.Error_Code.None)
	result, execute_error := engine.execute(&query, view, {Max_Solutions = 16})
	testing.expect_value(t, execute_error, engine.Error_Code.None)
	return result
}

@(test)
test_snapshot_queries_inferred_closure_after_source_destroy :: proc(t: ^testing.T) {
	source: store.Store
	testing.expect_value(t, store.init(&source), store.Error_Code.None)
	profile: rdfs.Profile
	profile_error, store_error := rdfs.init(&profile, &source)
	testing.expect_value(t, profile_error, rdfs.Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	add(t, &source, {rdf.iri("urn:Person"), rdf.iri(rdfs.RDFS_SUBCLASS), rdf.iri("urn:Agent")})
	add(t, &source, {rdf.iri("urn:ada"), rdf.iri(rdfs.RDF_TYPE), rdf.iri("urn:Person")})
	materialized := rdfs.materialize(&profile, &source)
	testing.expect_value(t, materialized.error, rule.Error_Code.None)

	snapshot: Snapshot
	testing.expect_value(t, init(&snapshot, &source), Error_Code.None)
	rdfs.destroy(&profile)
	store.destroy(&source)
	defer destroy(&snapshot)
	view := view(&snapshot)

	select_result := run(t, `SELECT ?person WHERE { ?person <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <urn:Agent> }`, view)
	defer engine.destroy(&select_result)
	testing.expect_value(t, engine.Row_Count(&select_result), 1)
	person, bound, valid := engine.Cell(&select_result, 0, 0)
	testing.expect(t, valid && bound)
	testing.expect_value(t, person.value, "urn:ada")

	ask_result := run(t, `ASK { <urn:ada> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <urn:Agent> }`, view)
	defer engine.destroy(&ask_result)
	ask, valid_ask := engine.Ask_Value(&ask_result)
	testing.expect(t, valid_ask && ask)

	construct_result := run(t, `CONSTRUCT { ?person <urn:hasType> ?kind } WHERE { ?person <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> ?kind }`, view)
	defer engine.destroy(&construct_result)
	testing.expect_value(t, engine.Triple_Count(&construct_result), 2)
}

@(private) Stop_State :: struct { calls: int }
@(private) stop_after_one :: proc(_: rdf.Quad, user_data: rawptr) -> bool {
	(cast(^Stop_State)user_data).calls += 1
	return false
}

@(test)
test_default_graph_constraints_named_rejection_and_early_stop :: proc(t: ^testing.T) {
	source: store.Store
	testing.expect_value(t, store.init(&source), store.Error_Code.None)
	add(t, &source, {rdf.iri("urn:a"), rdf.iri("urn:p"), rdf.iri("urn:o")})
	add(t, &source, {rdf.iri("urn:b"), rdf.iri("urn:p"), rdf.iri("urn:o")})
	snapshot: Snapshot
	testing.expect_value(t, init(&snapshot, &source), Error_Code.None)
	store.destroy(&source)
	defer destroy(&snapshot)
	closure := view(&snapshot)
	state: Stop_State
	error := dataset.scan(closure, {Has_Predicate = true, Predicate = rdf.iri("urn:p")}, stop_after_one, &state)
	testing.expect_value(t, error, dataset.Error_Code.None)
	testing.expect_value(t, state.calls, 1)
	named_error := dataset.scan(closure, {Graph_Mode = .Named, Graph = rdf.iri("urn:g")}, stop_after_one, &state)
	any_named_error := dataset.scan(closure, {Graph_Mode = .Any_Named}, stop_after_one, &state)
	testing.expect_value(t, named_error, dataset.Error_Code.Invalid_View)
	testing.expect_value(t, any_named_error, dataset.Error_Code.Invalid_View)
}

@(test)
test_snapshot_quad_limit_is_explicit_and_leaves_no_partial_snapshot :: proc(t: ^testing.T) {
	source: store.Store
	testing.expect_value(t, store.init(&source), store.Error_Code.None)
	defer store.destroy(&source)
	add(t, &source, {rdf.iri("urn:a"), rdf.iri("urn:p"), rdf.iri("urn:o")})
	add(t, &source, {rdf.iri("urn:b"), rdf.iri("urn:p"), rdf.iri("urn:o")})

	snapshot: Snapshot
	testing.expect_value(t, init(&snapshot, &source, {max_quads = 1}), Error_Code.Quad_Limit)
	testing.expect_value(t, quad_count(&snapshot), 0)
	testing.expect_value(t, init(&snapshot, &source, {max_quads = -1}), Error_Code.Invalid_Option)
	testing.expect_value(t, quad_count(&snapshot), 0)
}

@(test)
test_adopted_store_snapshot_outlives_source_handle_and_reuses_indexed_scan :: proc(t: ^testing.T) {
	source: store.Store
	testing.expect_value(t, store.init(&source), store.Error_Code.None)
	add(t, &source, {rdf.iri("urn:ada"), rdf.iri("urn:knows"), rdf.iri("urn:bert")})
	add(t, &source, {rdf.iri("urn:ada"), rdf.iri("urn:knows"), rdf.iri("urn:cora")})

	snapshot: Snapshot
	adopt_store(&snapshot, &source)
	defer destroy(&snapshot)
	testing.expect_value(t, store.fact_count(&source), 0)
	store.destroy(&source)
	testing.expect_value(t, quad_count(&snapshot), 2)

	state: Stop_State
	closure := view(&snapshot)
	scan_error := dataset.scan(closure, {Has_Predicate = true, Predicate = rdf.iri("urn:knows")}, stop_after_one, &state)
	testing.expect_value(t, scan_error, dataset.Error_Code.None)
	testing.expect_value(t, state.calls, 1)

	result := run(t, `SELECT ?friend WHERE { <urn:ada> <urn:knows> ?friend } ORDER BY ?friend`, closure)
	defer engine.destroy(&result)
	testing.expect_value(t, engine.Row_Count(&result), 2)
	first, first_bound, first_valid := engine.Cell(&result, 0, 0)
	second, second_bound, second_valid := engine.Cell(&result, 1, 0)
	testing.expect(t, first_valid && first_bound && second_valid && second_bound)
	testing.expect_value(t, first.value, "urn:bert")
	testing.expect_value(t, second.value, "urn:cora")
}

@(test)
test_adopted_store_snapshot_queries_materialized_rdfs_closure :: proc(t: ^testing.T) {
	source: store.Store
	testing.expect_value(t, store.init(&source), store.Error_Code.None)
	profile: rdfs.Profile
	profile_error, store_error := rdfs.init(&profile, &source)
	testing.expect_value(t, profile_error, rdfs.Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	add(t, &source, {rdf.iri("urn:Person"), rdf.iri(rdfs.RDFS_SUBCLASS), rdf.iri("urn:Agent")})
	add(t, &source, {rdf.iri("urn:ada"), rdf.iri(rdfs.RDF_TYPE), rdf.iri("urn:Person")})
	materialized := rdfs.materialize(&profile, &source)
	testing.expect_value(t, materialized.error, rule.Error_Code.None)
	rdfs.destroy(&profile)

	snapshot: Snapshot
	adopt_store(&snapshot, &source)
	defer destroy(&snapshot)
	result := run(t, `SELECT ?person WHERE { ?person <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <urn:Agent> }`, view(&snapshot))
	defer engine.destroy(&result)
	testing.expect_value(t, engine.Row_Count(&result), 1)
	person, bound, valid := engine.Cell(&result, 0, 0)
	testing.expect(t, valid && bound)
	testing.expect_value(t, person.value, "urn:ada")
}

@(test)
test_indexed_view_reuses_live_store_identity_and_match_contract :: proc(t: ^testing.T) {
	source: store.Store
	testing.expect_value(t, store.init(&source), store.Error_Code.None)
	defer store.destroy(&source)

	first_scope := rdf.new_blank_node_scope()
	second_scope := rdf.new_blank_node_scope()
	add(t, &source, {rdf.blank_node("same", first_scope), rdf.iri("urn:p"), rdf.language_literal("value", "EN")})
	add(t, &source, {rdf.iri("urn:other"), rdf.iri("urn:p"), rdf.iri("urn:o")})
	add(t, &source, {rdf.iri("urn:other"), rdf.iri("urn:q"), rdf.iri("urn:o")})

	live := indexed_view(&source)
	state: Stop_State
	error := dataset.scan(live, {Has_Predicate = true, Predicate = rdf.iri("urn:p")}, stop_after_one, &state)
	testing.expect_value(t, error, dataset.Error_Code.None)
	testing.expect_value(t, state.calls, 1)

	matching_scope := Stop_State{}
	matching_pattern := dataset.Quad_Pattern{Has_Subject = true, Subject = rdf.blank_node("same", first_scope)}
	testing.expect_value(t, dataset.scan(live, matching_pattern, stop_after_one, &matching_scope), dataset.Error_Code.None)
	testing.expect_value(t, matching_scope.calls, 1)
	different_scope := Stop_State{}
	different_pattern := dataset.Quad_Pattern{Has_Subject = true, Subject = rdf.blank_node("same", second_scope)}
	testing.expect_value(t, dataset.scan(live, different_pattern, stop_after_one, &different_scope), dataset.Error_Code.None)
	testing.expect_value(t, different_scope.calls, 0)

	named_error := dataset.scan(live, {Graph_Mode = .Named, Graph = rdf.iri("urn:g")}, stop_after_one, &state)
	any_named_error := dataset.scan(live, {Graph_Mode = .Any_Named}, stop_after_one, &state)
	testing.expect_value(t, named_error, dataset.Error_Code.Invalid_View)
	testing.expect_value(t, any_named_error, dataset.Error_Code.Invalid_View)
}

@(test)
test_indexed_view_matches_snapshot_query_results_while_source_is_live :: proc(t: ^testing.T) {
	source: store.Store
	testing.expect_value(t, store.init(&source), store.Error_Code.None)
	defer store.destroy(&source)
	add(t, &source, {rdf.iri("urn:ada"), rdf.iri("urn:knows"), rdf.iri("urn:bert")})
	add(t, &source, {rdf.iri("urn:ada"), rdf.iri("urn:knows"), rdf.iri("urn:cora")})

	snapshot: Snapshot
	testing.expect_value(t, init(&snapshot, &source), Error_Code.None)
	defer destroy(&snapshot)
	live_result := run(t, `SELECT ?friend WHERE { <urn:ada> <urn:knows> ?friend } ORDER BY ?friend`, indexed_view(&source))
	defer engine.destroy(&live_result)
	snapshot_result := run(t, `SELECT ?friend WHERE { <urn:ada> <urn:knows> ?friend } ORDER BY ?friend`, view(&snapshot))
	defer engine.destroy(&snapshot_result)
	testing.expect_value(t, engine.Row_Count(&live_result), engine.Row_Count(&snapshot_result))
	for index in 0..<engine.Row_Count(&live_result) {
		live_term, live_bound, live_ok := engine.Cell(&live_result, index, 0)
		snapshot_term, snapshot_bound, snapshot_ok := engine.Cell(&snapshot_result, index, 0)
		testing.expect(t, live_ok && live_bound && snapshot_ok && snapshot_bound)
		testing.expect_value(t, live_term.value, snapshot_term.value)
	}
}
