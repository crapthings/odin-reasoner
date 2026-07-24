package owlrl

import "core:testing"
import rdf "odin-rdf:rdf"
import rdfs "../rdfs"
import rule "../rule"
import store "../store"
import term "../term"

@(private) add_one_of_fact :: proc(t: ^testing.T, target: ^store.Store, triple: rdf.Triple) {
	added, error := store.insert_triple(target, triple)
	testing.expect(t, added)
	testing.expect_value(t, error, store.Error_Code.None)
}

@(private) has_one_of_fact :: proc(target: ^store.Store, triple: rdf.Triple) -> bool {
	fact := store.Fact{
		subject = term.id_for(&target.dictionary, triple.subject),
		predicate = term.id_for(&target.dictionary, triple.predicate),
		object = term.id_for(&target.dictionary, triple.object),
	}
	return fact.subject != term.INVALID_TERM_ID && fact.predicate != term.INVALID_TERM_ID && fact.object != term.INVALID_TERM_ID && store.contains(target, fact)
}

@(test)
test_one_of_list_rule_reaches_joint_rdfs_fixpoint :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)

	class, super, a, b := rdf.iri("urn:Choice"), rdf.iri("urn:Super"), rdf.iri("urn:a"), rdf.iri("urn:b")
	n1, n2 := rdf.blank_node("n1", rdf.Blank_Node_Scope(7)), rdf.blank_node("n2", rdf.Blank_Node_Scope(7))
	add_one_of_fact(t, &target, {class, rdf.iri(OWL_ONE_OF), n1})
	add_one_of_fact(t, &target, {n1, rdf.iri(RDF_FIRST), a})
	add_one_of_fact(t, &target, {n1, rdf.iri(RDF_REST), n2})
	add_one_of_fact(t, &target, {n2, rdf.iri(RDF_FIRST), b})
	add_one_of_fact(t, &target, {n2, rdf.iri(RDF_REST), rdf.iri(RDF_NIL)})
	add_one_of_fact(t, &target, {class, rdf.iri(rdfs.RDFS_SUBCLASS), super})

	result := materialize_one_of(&profile, &target, {max_list_items = 4})
	testing.expect_value(t, result.error, One_Of_Error_Code.None)
	testing.expect(t, has_one_of_fact(&target, {a, rdf.iri(rdfs.RDF_TYPE), class}))
	testing.expect(t, has_one_of_fact(&target, {b, rdf.iri(rdfs.RDF_TYPE), class}))
	testing.expect(t, has_one_of_fact(&target, {a, rdf.iri(rdfs.RDF_TYPE), super}))
	testing.expect(t, has_one_of_fact(&target, {b, rdf.iri(rdfs.RDF_TYPE), super}))
}

@(test)
test_one_of_malformed_list_and_configured_limit_do_not_commit :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)

	class, node := rdf.iri("urn:Choice"), rdf.blank_node("bad", rdf.Blank_Node_Scope(8))
	add_one_of_fact(t, &target, {class, rdf.iri(OWL_ONE_OF), node})
	add_one_of_fact(t, &target, {node, rdf.iri(RDF_FIRST), rdf.iri("urn:a")})
	before := store.fact_count(&target)
	malformed := materialize_one_of(&profile, &target)
	testing.expect_value(t, malformed.error, One_Of_Error_Code.List_Error)
	testing.expect_value(t, malformed.list_error, List_Error_Code.Missing_Rest)
	testing.expect_value(t, store.fact_count(&target), before)
	limited := materialize_one_of(&profile, &target, {max_derivations = 1})
	testing.expect_value(t, limited.error, One_Of_Error_Code.Rule_Error)
	testing.expect_value(t, limited.rule_error, rule.Error_Code.Max_Derivations)
	testing.expect_value(t, store.fact_count(&target), before)
}
