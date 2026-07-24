package owlrl

import "core:testing"
import rdf "odin-rdf:rdf"
import rdfs "../rdfs"
import store "../store"
import term "../term"

@(test)
test_materialize_all_has_key_matches_every_list_property :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)

	class, p1, p2, p3 := rdf.iri("urn:key-class"), rdf.iri("urn:key-p1"), rdf.iri("urn:key-p2"), rdf.iri("urn:key-p3")
	left, right, different := rdf.iri("urn:key-left"), rdf.iri("urn:key-right"), rdf.iri("urn:key-different")
	n1, n2, n3 := rdf.blank_node("key-list-1", rdf.Blank_Node_Scope(71)), rdf.blank_node("key-list-2", rdf.Blank_Node_Scope(71)), rdf.blank_node("key-list-3", rdf.Blank_Node_Scope(71))
	add(t, &target, {class, rdf.iri(OWL_HAS_KEY), n1})
	add(t, &target, {n1, rdf.iri(RDF_FIRST), p1})
	add(t, &target, {n1, rdf.iri(RDF_REST), n2})
	add(t, &target, {n2, rdf.iri(RDF_FIRST), p2})
	add(t, &target, {n2, rdf.iri(RDF_REST), n3})
	add(t, &target, {n3, rdf.iri(RDF_FIRST), p3})
	add(t, &target, {n3, rdf.iri(RDF_REST), rdf.iri(RDF_NIL)})
	add(t, &target, {left, rdf.iri(rdfs.RDF_TYPE), class})
	add(t, &target, {right, rdf.iri(rdfs.RDF_TYPE), class})
	add(t, &target, {different, rdf.iri(rdfs.RDF_TYPE), class})
	add(t, &target, {left, p1, rdf.literal("same")})
	add(t, &target, {right, p1, rdf.literal("same")})
	add(t, &target, {different, p1, rdf.literal("same")})
	add(t, &target, {left, p2, rdf.iri("urn:key-object")})
	add(t, &target, {right, p2, rdf.iri("urn:key-object")})
	add(t, &target, {different, p2, rdf.iri("urn:key-object")})
	add(t, &target, {left, p3, rdf.iri("urn:key-third")})
	add(t, &target, {right, p3, rdf.iri("urn:key-third")})
	add(t, &target, {different, p3, rdf.iri("urn:other-third")})

	result := materialize_all(&profile, &target)
	testing.expect_value(t, result.error, Materialize_All_Error_Code.None)
	testing.expect(t, has(&target, {left, rdf.iri(OWL_SAME_AS), right}))
	testing.expect(t, !has(&target, {left, rdf.iri(OWL_SAME_AS), different}))
	derived := store.id_for_fact(&target, {subject = term.id_for(&target.dictionary, left), predicate = term.id_for(&target.dictionary, rdf.iri(OWL_SAME_AS)), object = term.id_for(&target.dictionary, right)})
	derivation, found := closure_derivation_for(&profile, derived)
	testing.expect(t, found)
	testing.expect_value(t, derivation.rule_id, OWL_RL_PRP_KEY)
	testing.expect(t, closure_supports(derivation, store.id_for_fact(&target, {subject = term.id_for(&target.dictionary, n3), predicate = term.id_for(&target.dictionary, rdf.iri(RDF_FIRST)), object = term.id_for(&target.dictionary, p3)})))
	testing.expect(t, closure_supports(derivation, store.id_for_fact(&target, {subject = term.id_for(&target.dictionary, left), predicate = term.id_for(&target.dictionary, p3), object = term.id_for(&target.dictionary, rdf.iri("urn:key-third"))})))
}

@(test)
test_materialize_all_has_key_empty_list_matches_class_instances :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)

	class := rdf.iri("urn:empty-key-class")
	left, right := rdf.iri("urn:empty-key-left"), rdf.iri("urn:empty-key-right")
	add(t, &target, {class, rdf.iri(OWL_HAS_KEY), rdf.iri(RDF_NIL)})
	add(t, &target, {left, rdf.iri(rdfs.RDF_TYPE), class})
	add(t, &target, {right, rdf.iri(rdfs.RDF_TYPE), class})

	result := materialize_all(&profile, &target)
	testing.expect_value(t, result.error, Materialize_All_Error_Code.None)
	testing.expect(t, has(&target, {left, rdf.iri(OWL_SAME_AS), right}))
}

@(test)
test_materialize_all_has_key_malformed_list_is_transactional :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)

	class, property := rdf.iri("urn:broken-key-class"), rdf.iri("urn:broken-key-property")
	head := rdf.blank_node("broken-key-list", rdf.Blank_Node_Scope(72))
	left, right := rdf.iri("urn:broken-key-left"), rdf.iri("urn:broken-key-right")
	add(t, &target, {class, rdf.iri(OWL_HAS_KEY), head})
	add(t, &target, {head, rdf.iri(RDF_FIRST), property})
	add(t, &target, {left, rdf.iri(rdfs.RDF_TYPE), class})
	add(t, &target, {right, rdf.iri(rdfs.RDF_TYPE), class})
	add(t, &target, {left, property, rdf.iri("urn:key-object")})
	add(t, &target, {right, property, rdf.iri("urn:key-object")})
	before := store.fact_count(&target)

	result := materialize_all(&profile, &target)
	testing.expect_value(t, result.error, Materialize_All_Error_Code.List_Error)
	testing.expect_value(t, result.list_error, List_Error_Code.Missing_Rest)
	testing.expect_value(t, store.fact_count(&target), before)
	testing.expect(t, !has(&target, {left, rdf.iri(OWL_SAME_AS), right}))
}
