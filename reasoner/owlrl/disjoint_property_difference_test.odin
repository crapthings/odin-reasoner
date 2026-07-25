package owlrl

import "core:testing"
import rdf "odin-rdf:rdf"
import rdfs "../rdfs"
import store "../store"
import term "../term"

@(test)
test_disjoint_property_difference_derives_binary_and_list_based_w3c_shapes :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)

	property_disjoint := rdf.iri(OWL_PROPERTY_DISJOINT_WITH)
	father, mother := rdf.iri("urn:father"), rdf.iri("urn:mother")
	stewie, peter, lois := rdf.iri("urn:stewie"), rdf.iri("urn:peter"), rdf.iri("urn:lois")
	add(t, &target, {father, property_disjoint, mother})
	add(t, &target, {stewie, father, peter})
	add(t, &target, {stewie, mother, lois})

	group := rdf.blank_node("disjoint-group", rdf.Blank_Node_Scope(72))
	head, tail := rdf.blank_node("disjoint-head", rdf.Blank_Node_Scope(72)), rdf.blank_node("disjoint-tail", rdf.Blank_Node_Scope(72))
	p1, p2 := rdf.iri("urn:p1"), rdf.iri("urn:p2")
	a, b, shared := rdf.iri("urn:a"), rdf.iri("urn:b"), rdf.iri("urn:shared")
	add(t, &target, {group, rdf.iri(rdfs.RDF_TYPE), rdf.iri(OWL_ALL_DISJOINT_PROPERTIES)})
	add(t, &target, {group, rdf.iri(OWL_MEMBERS), head})
	add(t, &target, {head, rdf.iri(RDF_FIRST), p1})
	add(t, &target, {head, rdf.iri(RDF_REST), tail})
	add(t, &target, {tail, rdf.iri(RDF_FIRST), p2})
	add(t, &target, {tail, rdf.iri(RDF_REST), rdf.iri(RDF_NIL)})
	add(t, &target, {a, p1, shared})
	add(t, &target, {b, p2, shared})

	result := materialize_all(&profile, &target, {max_list_items = 2})
	testing.expect_value(t, result.error, Materialize_All_Error_Code.None)
	testing.expect(t, has(&target, {peter, rdf.iri(OWL_DIFFERENT_FROM), lois}))
	testing.expect(t, has(&target, {a, rdf.iri(OWL_DIFFERENT_FROM), b}))

	binary_difference := store.id_for_fact(&target, {subject = term.id_for(&target.dictionary, peter), predicate = term.id_for(&target.dictionary, rdf.iri(OWL_DIFFERENT_FROM)), object = term.id_for(&target.dictionary, lois)})
	binary_derivation, binary_found := closure_derivation_for(&profile, binary_difference)
	testing.expect(t, binary_found)
	testing.expect_value(t, binary_derivation.rule_id, OWL_RDF_PROPERTY_DISJOINT_DIFFERENCE)
	testing.expect(t, closure_supports(binary_derivation, store.id_for_fact(&target, {subject = term.id_for(&target.dictionary, father), predicate = term.id_for(&target.dictionary, property_disjoint), object = term.id_for(&target.dictionary, mother)})))

	list_difference := store.id_for_fact(&target, {subject = term.id_for(&target.dictionary, a), predicate = term.id_for(&target.dictionary, rdf.iri(OWL_DIFFERENT_FROM)), object = term.id_for(&target.dictionary, b)})
	list_derivation, list_found := closure_derivation_for(&profile, list_difference)
	testing.expect(t, list_found)
	testing.expect_value(t, list_derivation.rule_id, OWL_RDF_PROPERTY_DISJOINT_DIFFERENCE)
	testing.expect(t, closure_supports(list_derivation, store.id_for_fact(&target, {subject = term.id_for(&target.dictionary, group), predicate = term.id_for(&target.dictionary, rdf.iri(rdfs.RDF_TYPE)), object = term.id_for(&target.dictionary, rdf.iri(OWL_ALL_DISJOINT_PROPERTIES))})))
	testing.expect(t, closure_supports(list_derivation, store.id_for_fact(&target, {subject = term.id_for(&target.dictionary, group), predicate = term.id_for(&target.dictionary, rdf.iri(OWL_MEMBERS)), object = term.id_for(&target.dictionary, head)})))
}

@(test)
test_disjoint_property_difference_keeps_literal_subject_heads_opt_in :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)

	p1, p2, subject := rdf.iri("urn:p1"), rdf.iri("urn:p2"), rdf.iri("urn:subject")
	left, right := rdf.literal("left"), rdf.literal("right")
	add(t, &target, {p1, rdf.iri(OWL_PROPERTY_DISJOINT_WITH), p2})
	add(t, &target, {subject, p1, left})
	add(t, &target, {subject, p2, right})

	strict := materialize_all(&profile, &target)
	testing.expect_value(t, strict.error, Materialize_All_Error_Code.None)
	difference := store.Fact{subject = term.id_for(&target.dictionary, left), predicate = term.id_for(&target.dictionary, rdf.iri(OWL_DIFFERENT_FROM)), object = term.id_for(&target.dictionary, right)}
	testing.expect_value(t, store.id_for_fact(&target, difference), store.INVALID_FACT_ID)

	generalized := materialize_all(&profile, &target, {generalized_heads = true})
	testing.expect_value(t, generalized.error, Materialize_All_Error_Code.None)
	testing.expect(t, store.id_for_fact(&target, difference) != store.INVALID_FACT_ID)
}
