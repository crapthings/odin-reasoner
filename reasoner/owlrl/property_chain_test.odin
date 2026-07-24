package owlrl

import "core:testing"
import rdf "odin-rdf:rdf"
import rdfs "../rdfs"
import store "../store"
import term "../term"

@(private) add_chain_test_fact :: proc(t: ^testing.T, target: ^store.Store, triple: rdf.Triple) {
	added, error := store.insert_triple(target, triple)
	testing.expect(t, added)
	testing.expect_value(t, error, store.Error_Code.None)
}

@(private) has_property_chain_fact :: proc(target: ^store.Store, triple: rdf.Triple) -> bool {
	fact := store.Fact{
		subject = term.id_for(&target.dictionary, triple.subject),
		predicate = term.id_for(&target.dictionary, triple.predicate),
		object = term.id_for(&target.dictionary, triple.object),
	}
	return fact.subject != term.INVALID_TERM_ID && fact.predicate != term.INVALID_TERM_ID && fact.object != term.INVALID_TERM_ID && store.contains(target, fact)
}

@(test)
test_property_chain_materializes_exact_paths_and_reaches_rdfs_fixpoint :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)

	chain, super := rdf.iri("urn:chain"), rdf.iri("urn:super")
	p1, p2, p3 := rdf.iri("urn:p1"), rdf.iri("urn:p2"), rdf.iri("urn:p3")
	a, b, c, d := rdf.iri("urn:a"), rdf.iri("urn:b"), rdf.iri("urn:c"), rdf.iri("urn:d")
	x, y, z := rdf.iri("urn:x"), rdf.iri("urn:y"), rdf.iri("urn:z")
	n1, n2, n3 := rdf.blank_node("chain-1", rdf.Blank_Node_Scope(10)), rdf.blank_node("chain-2", rdf.Blank_Node_Scope(10)), rdf.blank_node("chain-3", rdf.Blank_Node_Scope(10))
	add_chain_test_fact(t, &target, {chain, rdf.iri(OWL_PROPERTY_CHAIN_AXIOM), n1})
	add_chain_test_fact(t, &target, {n1, rdf.iri(RDF_FIRST), p1})
	add_chain_test_fact(t, &target, {n1, rdf.iri(RDF_REST), n2})
	add_chain_test_fact(t, &target, {n2, rdf.iri(RDF_FIRST), p2})
	add_chain_test_fact(t, &target, {n2, rdf.iri(RDF_REST), n3})
	add_chain_test_fact(t, &target, {n3, rdf.iri(RDF_FIRST), p3})
	add_chain_test_fact(t, &target, {n3, rdf.iri(RDF_REST), rdf.iri(RDF_NIL)})
	add_chain_test_fact(t, &target, {chain, rdf.iri(rdfs.RDFS_SUBPROPERTY), super})
	add_chain_test_fact(t, &target, {a, p1, b})
	add_chain_test_fact(t, &target, {b, p2, c})
	add_chain_test_fact(t, &target, {c, p3, d})
	add_chain_test_fact(t, &target, {x, p1, y})
	add_chain_test_fact(t, &target, {y, p2, z})
	add_chain_test_fact(t, &target, {z, p3, x})

	result := materialize_property_chains(&profile, &target, {max_list_items = 4, max_path_states = 8})
	testing.expect_value(t, result.error, Property_Chain_Error_Code.None)
	testing.expect(t, has_property_chain_fact(&target, {a, chain, d}))
	testing.expect(t, has_property_chain_fact(&target, {a, super, d}))
	testing.expect(t, has_property_chain_fact(&target, {x, chain, x}))
	testing.expect(t, !has_property_chain_fact(&target, {a, chain, x}))
	testing.expect(t, !has_property_chain_fact(&target, {x, chain, d}))
}

@(test)
test_property_chain_short_list_does_not_commit :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)

	chain, p := rdf.iri("urn:bad-chain"), rdf.iri("urn:p")
	node := rdf.blank_node("one-item", rdf.Blank_Node_Scope(11))
	add_chain_test_fact(t, &target, {chain, rdf.iri(OWL_PROPERTY_CHAIN_AXIOM), node})
	add_chain_test_fact(t, &target, {node, rdf.iri(RDF_FIRST), p})
	add_chain_test_fact(t, &target, {node, rdf.iri(RDF_REST), rdf.iri(RDF_NIL)})
	before := store.fact_count(&target)
	short := materialize_property_chains(&profile, &target)
	testing.expect_value(t, short.error, Property_Chain_Error_Code.Chain_Too_Short)
	testing.expect_value(t, store.fact_count(&target), before)
}

@(test)
test_property_chain_path_limit_does_not_commit :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)

	chain, p1, p2 := rdf.iri("urn:bounded-chain"), rdf.iri("urn:p1"), rdf.iri("urn:p2")
	n1, n2 := rdf.blank_node("bounded-1", rdf.Blank_Node_Scope(12)), rdf.blank_node("bounded-2", rdf.Blank_Node_Scope(12))
	add_chain_test_fact(t, &target, {chain, rdf.iri(OWL_PROPERTY_CHAIN_AXIOM), n1})
	add_chain_test_fact(t, &target, {n1, rdf.iri(RDF_FIRST), p1})
	add_chain_test_fact(t, &target, {n1, rdf.iri(RDF_REST), n2})
	add_chain_test_fact(t, &target, {n2, rdf.iri(RDF_FIRST), p2})
	add_chain_test_fact(t, &target, {n2, rdf.iri(RDF_REST), rdf.iri(RDF_NIL)})
	add_chain_test_fact(t, &target, {rdf.iri("urn:a"), p1, rdf.iri("urn:b")})
	add_chain_test_fact(t, &target, {rdf.iri("urn:x"), p1, rdf.iri("urn:y")})
	before := store.fact_count(&target)
	limited := materialize_property_chains(&profile, &target, {max_path_states = 1})
	testing.expect_value(t, limited.error, Property_Chain_Error_Code.Path_State_Limit)
	testing.expect_value(t, store.fact_count(&target), before)
}
