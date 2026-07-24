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
