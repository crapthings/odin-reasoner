package owlrl

import "core:testing"
import rdf "odin-rdf:rdf"
import rdfs "../rdfs"
import rule "../rule"
import store "../store"
import term "../term"

@(private) add_union_fact :: proc(t: ^testing.T, target: ^store.Store, triple: rdf.Triple) {
	added, error := store.insert_triple(target, triple)
	testing.expect(t, added)
	testing.expect_value(t, error, store.Error_Code.None)
}

@(private) has_union_fact :: proc(target: ^store.Store, triple: rdf.Triple) -> bool {
	fact := store.Fact{
		subject = term.id_for(&target.dictionary, triple.subject),
		predicate = term.id_for(&target.dictionary, triple.predicate),
		object = term.id_for(&target.dictionary, triple.object),
	}
	return fact.subject != term.INVALID_TERM_ID && fact.predicate != term.INVALID_TERM_ID && fact.object != term.INVALID_TERM_ID && store.contains(target, fact)
}

@(test)
test_union_list_rule_reaches_joint_rdfs_fixpoint :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)

	combined_class, left, right, super := rdf.iri("urn:Union"), rdf.iri("urn:Left"), rdf.iri("urn:Right"), rdf.iri("urn:Super")
	a, b := rdf.iri("urn:a"), rdf.iri("urn:b")
	n1, n2 := rdf.blank_node("union-1", rdf.Blank_Node_Scope(13)), rdf.blank_node("union-2", rdf.Blank_Node_Scope(13))
	add_union_fact(t, &target, {combined_class, rdf.iri(OWL_UNION_OF), n1})
	add_union_fact(t, &target, {n1, rdf.iri(RDF_FIRST), left})
	add_union_fact(t, &target, {n1, rdf.iri(RDF_REST), n2})
	add_union_fact(t, &target, {n2, rdf.iri(RDF_FIRST), right})
	add_union_fact(t, &target, {n2, rdf.iri(RDF_REST), rdf.iri(RDF_NIL)})
	add_union_fact(t, &target, {combined_class, rdf.iri(rdfs.RDFS_SUBCLASS), super})
	add_union_fact(t, &target, {a, rdf.iri(rdfs.RDF_TYPE), left})
	add_union_fact(t, &target, {b, rdf.iri(rdfs.RDF_TYPE), right})

	result := materialize_union(&profile, &target, {max_list_items = 4})
	testing.expect_value(t, result.error, Union_Error_Code.None)
	testing.expect(t, has_union_fact(&target, {a, rdf.iri(rdfs.RDF_TYPE), combined_class}))
	testing.expect(t, has_union_fact(&target, {b, rdf.iri(rdfs.RDF_TYPE), combined_class}))
	testing.expect(t, has_union_fact(&target, {a, rdf.iri(rdfs.RDF_TYPE), super}))
	testing.expect(t, has_union_fact(&target, {b, rdf.iri(rdfs.RDF_TYPE), super}))
}

@(test)
test_union_empty_list_is_finite_and_errors_do_not_commit :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)

	empty_union, unrelated := rdf.iri("urn:EmptyUnion"), rdf.iri("urn:unrelated")
	add_union_fact(t, &target, {empty_union, rdf.iri(OWL_UNION_OF), rdf.iri(RDF_NIL)})
	add_union_fact(t, &target, {unrelated, rdf.iri(rdfs.RDF_TYPE), rdf.iri("urn:Class")})
	empty := materialize_union(&profile, &target)
	testing.expect_value(t, empty.error, Union_Error_Code.None)
	testing.expect(t, !has_union_fact(&target, {unrelated, rdf.iri(rdfs.RDF_TYPE), empty_union}))

	broken := rdf.blank_node("broken-union", rdf.Blank_Node_Scope(14))
	add_union_fact(t, &target, {rdf.iri("urn:BrokenUnion"), rdf.iri(OWL_UNION_OF), broken})
	add_union_fact(t, &target, {broken, rdf.iri(RDF_FIRST), rdf.iri("urn:Class")})
	before := store.fact_count(&target)
	malformed := materialize_union(&profile, &target)
	testing.expect_value(t, malformed.error, Union_Error_Code.List_Error)
	testing.expect_value(t, malformed.list_error, List_Error_Code.Missing_Rest)
	testing.expect_value(t, store.fact_count(&target), before)
	limited := materialize_union(&profile, &target, {max_derivations = 1})
	testing.expect_value(t, limited.error, Union_Error_Code.Rule_Error)
	testing.expect_value(t, limited.rule_error, rule.Error_Code.Max_Derivations)
	testing.expect_value(t, store.fact_count(&target), before)
}
