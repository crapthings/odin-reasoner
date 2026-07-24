package owlrl

import "core:testing"
import rdf "odin-rdf:rdf"
import store "../store"

@(private) add_list_fact :: proc(t: ^testing.T, target: ^store.Store, triple: rdf.Triple) {
	added, error := store.insert_triple(target, triple)
	testing.expect(t, added)
	testing.expect_value(t, error, store.Error_Code.None)
}

@(private) init_list_profile :: proc(t: ^testing.T, target: ^store.Store, profile: ^Profile) {
	testing.expect_value(t, store.init(target), store.Error_Code.None)
	profile_error, store_error := init(profile, target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
}

@(test)
test_read_list_owned_term_ids_and_empty_list :: proc(t: ^testing.T) {
	target: store.Store
	profile: Profile
	init_list_profile(t, &target, &profile)
	defer destroy(&profile)
	defer store.destroy(&target)
	first, rest := rdf.iri(RDF_FIRST), rdf.iri(RDF_REST)
	n1 := rdf.blank_node("n1", rdf.Blank_Node_Scope(1))
	n2 := rdf.blank_node("n2", rdf.Blank_Node_Scope(1))
	a, b := rdf.iri("urn:a"), rdf.literal("b")
	add_list_fact(t, &target, {n1, first, a})
	add_list_fact(t, &target, {n1, rest, n2})
	add_list_fact(t, &target, {n2, first, b})
	add_list_fact(t, &target, {n2, rest, rdf.iri(RDF_NIL)})
	list: List
	init_list(&list)
	defer destroy_list(&list)
	head := store.id_for_term(&target, n1)
	testing.expect_value(t, read_list(&profile, &target, head, &list), List_Error_Code.None)
	testing.expect_value(t, list_count(&list), 2)
	item0, found0 := list_item_at(&list, 0)
	item1, found1 := list_item_at(&list, 1)
	testing.expect(t, found0 && found1)
	testing.expect_value(t, item0, store.id_for_term(&target, a))
	testing.expect_value(t, item1, store.id_for_term(&target, b))
	testing.expect_value(t, read_list(&profile, &target, store.id_for_term(&target, rdf.iri(RDF_NIL)), &list), List_Error_Code.None)
	testing.expect_value(t, list_count(&list), 0)
}

@(test)
test_read_list_rejects_malformed_cycle_and_limit_without_partial_output :: proc(t: ^testing.T) {
	target: store.Store
	profile: Profile
	init_list_profile(t, &target, &profile)
	defer destroy(&profile)
	defer store.destroy(&target)
	first, rest, nil_term := rdf.iri(RDF_FIRST), rdf.iri(RDF_REST), rdf.iri(RDF_NIL)
	multiple := rdf.blank_node("multiple", rdf.Blank_Node_Scope(2))
	add_list_fact(t, &target, {multiple, first, rdf.iri("urn:a")})
	add_list_fact(t, &target, {multiple, first, rdf.iri("urn:b")})
	add_list_fact(t, &target, {multiple, rest, nil_term})
	cycle := rdf.blank_node("cycle", rdf.Blank_Node_Scope(2))
	add_list_fact(t, &target, {cycle, first, rdf.iri("urn:c")})
	add_list_fact(t, &target, {cycle, rest, cycle})
	n1 := rdf.blank_node("n1", rdf.Blank_Node_Scope(2))
	n2 := rdf.blank_node("n2", rdf.Blank_Node_Scope(2))
	add_list_fact(t, &target, {n1, first, rdf.iri("urn:one")})
	add_list_fact(t, &target, {n1, rest, n2})
	add_list_fact(t, &target, {n2, first, rdf.iri("urn:two")})
	add_list_fact(t, &target, {n2, rest, nil_term})
	list: List
	init_list(&list)
	defer destroy_list(&list)
	testing.expect_value(t, read_list(&profile, &target, store.id_for_term(&target, multiple), &list), List_Error_Code.Multiple_First)
	testing.expect_value(t, list_count(&list), 0)
	testing.expect_value(t, read_list(&profile, &target, store.id_for_term(&target, cycle), &list), List_Error_Code.Cycle)
	testing.expect_value(t, list_count(&list), 0)
	testing.expect_value(t, read_list(&profile, &target, store.id_for_term(&target, n1), &list, {max_items = 1}), List_Error_Code.Item_Limit)
	testing.expect_value(t, list_count(&list), 0)
}
