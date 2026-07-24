package owlrl

import "core:testing"
import rdf "odin-rdf:rdf"
import rdfs "../rdfs"
import rule "../rule"
import store "../store"
import term "../term"

@(private) add_intersection_fact :: proc(t: ^testing.T, target: ^store.Store, triple: rdf.Triple) {
	added, error := store.insert_triple(target, triple)
	testing.expect(t, added)
	testing.expect_value(t, error, store.Error_Code.None)
}

@(private) has_intersection_fact :: proc(target: ^store.Store, triple: rdf.Triple) -> bool {
	fact := store.Fact{
		subject = term.id_for(&target.dictionary, triple.subject),
		predicate = term.id_for(&target.dictionary, triple.predicate),
		object = term.id_for(&target.dictionary, triple.object),
	}
	return fact.subject != term.INVALID_TERM_ID && fact.predicate != term.INVALID_TERM_ID && fact.object != term.INVALID_TERM_ID && store.contains(target, fact)
}

@(test)
test_intersection_list_rules_reach_joint_rdfs_fixpoint :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)

	intersection, left, right, super := rdf.iri("urn:Intersection"), rdf.iri("urn:Left"), rdf.iri("urn:Right"), rdf.iri("urn:Super")
	x, y := rdf.iri("urn:x"), rdf.iri("urn:y")
	n1, n2 := rdf.blank_node("int-1", rdf.Blank_Node_Scope(9)), rdf.blank_node("int-2", rdf.Blank_Node_Scope(9))
	add_intersection_fact(t, &target, {intersection, rdf.iri(OWL_INTERSECTION_OF), n1})
	add_intersection_fact(t, &target, {n1, rdf.iri(RDF_FIRST), left})
	add_intersection_fact(t, &target, {n1, rdf.iri(RDF_REST), n2})
	add_intersection_fact(t, &target, {n2, rdf.iri(RDF_FIRST), right})
	add_intersection_fact(t, &target, {n2, rdf.iri(RDF_REST), rdf.iri(RDF_NIL)})
	add_intersection_fact(t, &target, {intersection, rdf.iri(rdfs.RDFS_SUBCLASS), super})
	add_intersection_fact(t, &target, {x, rdf.iri(rdfs.RDF_TYPE), left})
	add_intersection_fact(t, &target, {x, rdf.iri(rdfs.RDF_TYPE), right})
	add_intersection_fact(t, &target, {y, rdf.iri(rdfs.RDF_TYPE), intersection})

	result := materialize_intersection(&profile, &target, {max_list_items = 4})
	testing.expect_value(t, result.error, Intersection_Error_Code.None)
	testing.expect(t, has_intersection_fact(&target, {x, rdf.iri(rdfs.RDF_TYPE), intersection}))
	testing.expect(t, has_intersection_fact(&target, {x, rdf.iri(rdfs.RDF_TYPE), super}))
	testing.expect(t, has_intersection_fact(&target, {y, rdf.iri(rdfs.RDF_TYPE), left}))
	testing.expect(t, has_intersection_fact(&target, {y, rdf.iri(rdfs.RDF_TYPE), right}))
}

@(test)
test_intersection_empty_list_and_limit_do_not_commit :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)

	intersection := rdf.iri("urn:EmptyIntersection")
	add_intersection_fact(t, &target, {intersection, rdf.iri(OWL_INTERSECTION_OF), rdf.iri(RDF_NIL)})
	before := store.fact_count(&target)
	empty := materialize_intersection(&profile, &target)
	testing.expect_value(t, empty.error, Intersection_Error_Code.Empty_List)
	testing.expect_value(t, store.fact_count(&target), before)
	limited := materialize_intersection(&profile, &target, {max_derivations = 1})
	testing.expect_value(t, limited.error, Intersection_Error_Code.Rule_Error)
	testing.expect_value(t, limited.rule_error, rule.Error_Code.Max_Derivations)
	testing.expect_value(t, store.fact_count(&target), before)
}
