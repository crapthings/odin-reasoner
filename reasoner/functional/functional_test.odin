package functional

import "core:testing"
import rdf "odin-rdf:rdf"
import importer "../import"
import store "../store"

@(private) parse_into_store :: proc(t: ^testing.T, input: string, target: ^store.Store) -> Result {
	state: importer.Sink_State
	importer.init(&state, target)
	result := parse(input, importer.triple_sink, &state)
	testing.expect_value(t, state.last_error, store.Error_Code.None)
	return result
}

@(private) has_functional_triple :: proc(target: ^store.Store, triple: rdf.Triple) -> bool {
	return store.contains(target, {
		subject = store.id_for_term(target, triple.subject),
		predicate = store.id_for_term(target, triple.predicate),
		object = store.id_for_term(target, triple.object),
	})
}

@(test)
test_maps_binary_same_and_different_individual_axioms :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	input := `Prefix(: = <http://example.org/>) Ontology(SameIndividual(:a :b) DifferentIndividuals(:a :c))`
	result := parse_into_store(t, input, &target)
	testing.expect_value(t, result.code, Error_Code.None)
	testing.expect(t, has_functional_triple(&target, {rdf.iri("http://example.org/a"), rdf.iri("http://www.w3.org/2002/07/owl#sameAs"), rdf.iri("http://example.org/b")}))
	testing.expect(t, has_functional_triple(&target, {rdf.iri("http://example.org/a"), rdf.iri("http://www.w3.org/2002/07/owl#differentFrom"), rdf.iri("http://example.org/c")}))
}

@(test)
test_maps_nary_same_individual_with_declared_builtin_prefix_names :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	input := `Prefix(: = <http://example.org/>) Prefix(xsd: = <http://example.org/>) Prefix(rdf: = <http://example.org/>) Prefix(rdfs: = <http://example.org/>) Prefix(owl: = <http://example.org/>) Ontology(SameIndividual(:a xsd:b rdf:c rdfs:d owl:e))`
	result := parse_into_store(t, input, &target)
	testing.expect_value(t, result.code, Error_Code.None)
	same_as := rdf.iri("http://www.w3.org/2002/07/owl#sameAs")
	testing.expect(t, has_functional_triple(&target, {rdf.iri("http://example.org/a"), same_as, rdf.iri("http://example.org/b")}))
	testing.expect(t, has_functional_triple(&target, {rdf.iri("http://example.org/b"), same_as, rdf.iri("http://example.org/c")}))
	testing.expect(t, has_functional_triple(&target, {rdf.iri("http://example.org/c"), same_as, rdf.iri("http://example.org/d")}))
	testing.expect(t, has_functional_triple(&target, {rdf.iri("http://example.org/d"), same_as, rdf.iri("http://example.org/e")}))
}

@(test)
test_maps_nary_different_individual_to_all_different_list :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	input := `Prefix(: = <http://example.org/>) Ontology(DifferentIndividuals(:a :b :c))`
	result := parse_into_store(t, input, &target)
	testing.expect_value(t, result.code, Error_Code.None)
	testing.expect_value(t, store.fact_count(&target), 9)
	all_different := store.id_for_term(&target, rdf.iri("http://www.w3.org/2002/07/owl#AllDifferent"))
	rdf_type := store.id_for_term(&target, rdf.iri("http://www.w3.org/1999/02/22-rdf-syntax-ns#type"))
	members := store.id_for_term(&target, rdf.iri("http://www.w3.org/2002/07/owl#members"))
	found := false
	for index in 0..<store.fact_count(&target) {
		_, fact, _, fact_found := store.fact_at(&target, index)
		if fact_found && fact.predicate == rdf_type && fact.object == all_different { found = true; break }
	}
	testing.expect(t, found)
	found = false
	for index in 0..<store.fact_count(&target) {
		_, fact, _, fact_found := store.fact_at(&target, index)
		if fact_found && fact.predicate == members { found = true; break }
	}
	testing.expect(t, found)
}

@(test)
test_rejects_undeclared_prefix_before_emitting_an_axiom :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	result := parse_into_store(t, `Ontology(SameIndividual(:a :b))`, &target)
	testing.expect_value(t, result.code, Error_Code.Unknown_Prefix)
	testing.expect_value(t, store.fact_count(&target), 1)
}

@(test)
test_maps_selected_w3c_functional_syntax_cases :: proc(t: ^testing.T) {
	cases := []struct { input: string, expected: rdf.Triple }{
		{`Prefix(: = <http://example.org/>) Ontology(DifferentIndividuals(:a :b))`, {rdf.iri("http://example.org/a"), rdf.iri("http://www.w3.org/2002/07/owl#differentFrom"), rdf.iri("http://example.org/b")}},
		{`Prefix(: = <http://example.org/>) Ontology(SameIndividual(:a :b))`, {rdf.iri("http://example.org/a"), rdf.iri("http://www.w3.org/2002/07/owl#sameAs"), rdf.iri("http://example.org/b")}},
		{`Prefix(: = <http://example.org/>) Prefix(xsd: = <http://example.org/>) Prefix(rdf: = <http://example.org/>) Prefix(rdfs: = <http://example.org/>) Prefix(owl: = <http://example.org/>) Ontology(SameIndividual(:a xsd:b rdf:c rdfs:d owl:e))`, {rdf.iri("http://example.org/d"), rdf.iri("http://www.w3.org/2002/07/owl#sameAs"), rdf.iri("http://example.org/e")}},
	}
	for item in cases {
		target: store.Store
		testing.expect_value(t, store.init(&target), store.Error_Code.None)
		result := parse_into_store(t, item.input, &target)
		testing.expect_value(t, result.code, Error_Code.None)
		testing.expect(t, has_functional_triple(&target, item.expected))
		store.destroy(&target)
	}

	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	result := parse_into_store(t, `Prefix(: = <http://example.org/>) Ontology(DifferentIndividuals(:a :b :c))`, &target)
	testing.expect_value(t, result.code, Error_Code.None)
	testing.expect_value(t, store.fact_count(&target), 9)
	store.destroy(&target)
}
