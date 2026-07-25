package owlrl

import rdf "odin-rdf:rdf"
import store "../store"
import term "../term"

// Disjoint_Property_Difference_Error_Code reports the bounded RDF-Based
// semantic supplement which proves distinct resources from disjoint property
// assertions. It shares materialize_all's list and derivation bounds.
Disjoint_Property_Difference_Error_Code :: enum {
	None,
	Rule_Error,
	List_Error,
	Out_Of_Memory,
	Store_Error,
}

@(private) add_disjoint_property_difference :: proc(profile: ^Profile, target: ^store.Store, subject, object: term.Term_ID, remaining: int, added_count: ^int, generalized_heads: bool, provenance: ^Closure_Provenance, axiom_id, group_id, left_id, right_id: store.Fact_ID, list: ^List = nil) -> (Disjoint_Property_Difference_Error_Code, store.Error_Code) {
	if remaining >= 0 && added_count^ >= remaining do return .Rule_Error, .None
	subject_term, subject_ok := store.get_term(target, subject)
	predicate_term, predicate_ok := store.get_term(target, profile.terms.different_from)
	object_term, object_ok := store.get_term(target, object)
	if !subject_ok || !predicate_ok || !object_ok do return .Store_Error, .Invalid_Fact
	if !generalized_heads && rdf.validate_triple_structure({subject_term, predicate_term, object_term}) != .None do return .None, .None
	fact := store.Fact{subject = subject, predicate = profile.terms.different_from, object = object}
	if store.contains(target, fact) do return .None, .None
	added, insert_error := store.insert(target, fact, .Inferred)
	if insert_error != .None do return insert_error == .Out_Of_Memory ? .Out_Of_Memory : .Store_Error, insert_error
	if !added do return .None, .None
	added_count^ += 1
	if list != nil {
		if !append_list_derivation(provenance, store.id_for_fact(target, fact), OWL_RDF_PROPERTY_DISJOINT_DIFFERENCE, axiom_id, list, []store.Fact_ID{group_id, left_id, right_id}) do return .Out_Of_Memory, .Out_Of_Memory
	} else if !append_closure_derivation(provenance, store.id_for_fact(target, fact), OWL_RDF_PROPERTY_DISJOINT_DIFFERENCE, []store.Fact_ID{axiom_id, left_id, right_id}) {
		return .Out_Of_Memory, .Out_Of_Memory
	}
	return .None, .None
}

// emit_disjoint_property_difference_pair proves two resources different when
// two disjoint-property assertions share a subject or an object. The same
// rule serves binary owl:propertyDisjointWith and every pair in a valid
// owl:AllDisjointProperties member list.
@(private) emit_disjoint_property_difference_pair :: proc(profile: ^Profile, target: ^store.Store, left_property, right_property: term.Term_ID, remaining: int, added_count: ^int, generalized_heads: bool, provenance: ^Closure_Provenance, axiom_id, group_id: store.Fact_ID, list: ^List = nil) -> (Disjoint_Property_Difference_Error_Code, store.Error_Code) {
	fact_limit := store.fact_count(target)
	for left_index in 0..<fact_limit {
		left_id, left, _, left_found := store.fact_at(target, left_index)
		if !left_found do return .Store_Error, .Invalid_Fact
		if left.predicate != left_property do continue
		for right_index in 0..<fact_limit {
			right_id, right, _, right_found := store.fact_at(target, right_index)
			if !right_found do return .Store_Error, .Invalid_Fact
			if right.predicate != right_property do continue
			if left.subject == right.subject {
				error, store_error := add_disjoint_property_difference(profile, target, left.object, right.object, remaining, added_count, generalized_heads, provenance, axiom_id, group_id, left_id, right_id, list)
				if error != .None do return error, store_error
			}
			if left.object == right.object {
				error, store_error := add_disjoint_property_difference(profile, target, left.subject, right.subject, remaining, added_count, generalized_heads, provenance, axiom_id, group_id, left_id, right_id, list)
				if error != .None do return error, store_error
			}
		}
	}
	return .None, .None
}

// emit_disjoint_property_differences implements the finite RDF-Based
// consequence of property disjointness used by the W3C positive-entailment
// vectors. It intentionally does not treat a missing difference as a model
// witness or claim arbitrary full-OWL entailment.
@(private) emit_disjoint_property_differences :: proc(profile: ^Profile, target: ^store.Store, max_list_items, remaining: int, generalized_heads: bool, provenance: ^Closure_Provenance) -> (added_count: int, error: Disjoint_Property_Difference_Error_Code, list_error: List_Error_Code, store_error: store.Error_Code) {
	list: List
	init_list(&list)
	defer destroy_list(&list)
	fact_limit := store.fact_count(target)
	for axiom_index in 0..<fact_limit {
		axiom_id, axiom, _, axiom_found := store.fact_at(target, axiom_index)
		if !axiom_found do return added_count, .Store_Error, .None, .Invalid_Fact
		if axiom.predicate == profile.terms.property_disjoint_with {
			phase_error, phase_store_error := emit_disjoint_property_difference_pair(profile, target, axiom.subject, axiom.object, remaining, &added_count, generalized_heads, provenance, axiom_id, store.INVALID_FACT_ID)
			if phase_error != .None do return added_count, phase_error, .None, phase_store_error
			continue
		}
		if axiom.predicate != profile.terms.rdf_type || axiom.object != profile.terms.all_disjoint_properties do continue
		for members_index in 0..<fact_limit {
			members_id, members, _, members_found := store.fact_at(target, members_index)
			if !members_found do return added_count, .Store_Error, .None, .Invalid_Fact
			if members.subject != axiom.subject || members.predicate != profile.terms.members do continue
			if list_error = read_list(profile, target, members.object, &list, {max_items = max_list_items, generalized_heads = generalized_heads}); list_error != .None do return added_count, .List_Error, list_error, .None
			for left_index in 0..<list_count(&list) {
				left_property, left_found := list_item_at(&list, left_index)
				if !left_found do return added_count, .Store_Error, .None, .Invalid_Fact
				for right_index in left_index+1..<list_count(&list) {
					right_property, right_found := list_item_at(&list, right_index)
					if !right_found do return added_count, .Store_Error, .None, .Invalid_Fact
					phase_error, phase_store_error := emit_disjoint_property_difference_pair(profile, target, left_property, right_property, remaining, &added_count, generalized_heads, provenance, members_id, axiom_id, &list)
					if phase_error != .None do return added_count, phase_error, .None, phase_store_error
				}
			}
		}
	}
	return added_count, .None, .None, .None
}
