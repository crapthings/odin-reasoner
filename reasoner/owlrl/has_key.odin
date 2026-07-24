package owlrl

import store "../store"
import term "../term"

// Has_Key_Error_Code reports the dynamic W3C prp-key phase. It shares the
// complete closure's list and derivation limits with the other list phases.
Has_Key_Error_Code :: enum { None, Rule_Error, List_Error, Out_Of_Memory, Store_Error }

@(private) append_key_support :: proc(supports: ^[dynamic]store.Fact_ID, id: store.Fact_ID) -> Has_Key_Error_Code {
	_, append_error := append(supports, id)
	if append_error != nil do return .Out_Of_Memory
	return .None
}

// key_values_match finds one common object for every property in a decoded
// owl:hasKey list. The retained fact IDs are the first witness for each side
// of every key property, matching the closure's first-support convention.
@(private) key_values_match :: proc(profile: ^Profile, target: ^store.Store, list: ^List, left, right: term.Term_ID, supports: ^[dynamic]store.Fact_ID) -> (bool, Has_Key_Error_Code, store.Error_Code) {
	for property_index in 0..<list_count(list) {
		property, property_found := list_item_at(list, property_index)
		if !property_found do return false, .Store_Error, .Invalid_Fact
		matched := false
		for left_index in 0..<store.fact_count(target) {
			left_id, left_fact, _, left_found := store.fact_at(target, left_index)
			if !left_found do return false, .Store_Error, .Invalid_Fact
			if left_fact.subject != left || left_fact.predicate != property do continue
			for right_index in 0..<store.fact_count(target) {
				right_id, right_fact, _, right_found := store.fact_at(target, right_index)
				if !right_found do return false, .Store_Error, .Invalid_Fact
				if right_fact.subject != right || right_fact.predicate != property || right_fact.object != left_fact.object do continue
				if error := append_key_support(supports, left_id); error != .None do return false, error, .None
				if error := append_key_support(supports, right_id); error != .None do return false, error, .None
				matched = true
				break
			}
			if matched do break
		}
		if !matched do return false, .None, .None
	}
	return true, .None, .None
}

@(private) add_has_key_fact :: proc(profile: ^Profile, target: ^store.Store, subject, object: term.Term_ID, remaining: int, added_count: ^int, provenance: ^Closure_Provenance, declaration_id: store.Fact_ID, list: ^List, supports: []store.Fact_ID) -> (Has_Key_Error_Code, store.Error_Code) {
	if remaining >= 0 && added_count^ >= remaining do return .Rule_Error, .None
	fact := store.Fact{subject = subject, predicate = profile.terms.same_as, object = object}
	if store.contains(target, fact) do return .None, .None
	added, insert_error := store.insert(target, fact, .Inferred)
	if insert_error != .None do return .Store_Error, insert_error
	if added {
		added_count^ += 1
		fact_id := store.id_for_fact(target, fact)
		if fact_id == store.INVALID_FACT_ID || !append_list_derivation(provenance, fact_id, OWL_RL_PRP_KEY, declaration_id, list, supports) do return .Out_Of_Memory, .Out_Of_Memory
	}
	return .None, .None
}

// emit_has_keys implements the W3C prp-key direction over any well-formed
// RDF list length. A decoded empty key list intentionally matches every pair
// of instances of the declared class, as specified by the rule's empty
// conjunction of key-property conditions.
@(private) emit_has_keys :: proc(profile: ^Profile, target: ^store.Store, max_list_items, remaining: int, provenance: ^Closure_Provenance) -> (added_count: int, error: Has_Key_Error_Code, list_error: List_Error_Code, store_error: store.Error_Code) {
	list: List
	init_list(&list)
	defer destroy_list(&list)
	for declaration_index in 0..<store.fact_count(target) {
		declaration_id, declaration, _, declaration_found := store.fact_at(target, declaration_index)
		if !declaration_found do return added_count, .Store_Error, .None, .Invalid_Fact
		if declaration.predicate != profile.terms.has_key do continue
		if list_error = read_list(profile, target, declaration.object, &list, {max_items = max_list_items}); list_error != .None do return added_count, .List_Error, list_error, .None
		for left_index in 0..<store.fact_count(target) {
			left_type_id, left_type, _, left_found := store.fact_at(target, left_index)
			if !left_found do return added_count, .Store_Error, .None, .Invalid_Fact
			if left_type.predicate != profile.terms.rdf_type || left_type.object != declaration.subject do continue
			for right_index in 0..<store.fact_count(target) {
				right_type_id, right_type, _, right_found := store.fact_at(target, right_index)
				if !right_found do return added_count, .Store_Error, .None, .Invalid_Fact
				if right_type.predicate != profile.terms.rdf_type || right_type.object != declaration.subject do continue
				supports := make([dynamic]store.Fact_ID, 0, 2 + 2 * list_count(&list))
				if support_error := append_key_support(&supports, left_type_id); support_error != .None { delete(supports); return added_count, support_error, .None, .None }
				if support_error := append_key_support(&supports, right_type_id); support_error != .None { delete(supports); return added_count, support_error, .None, .None }
				matches, match_error, match_store_error := key_values_match(profile, target, &list, left_type.subject, right_type.subject, &supports)
				if match_error != .None { delete(supports); return added_count, match_error, .None, match_store_error }
				if matches {
					phase_error, insert_error := add_has_key_fact(profile, target, left_type.subject, right_type.subject, remaining, &added_count, provenance, declaration_id, &list, supports[:])
					if phase_error != .None { delete(supports); return added_count, phase_error, .None, insert_error }
				}
				delete(supports)
			}
		}
	}
	return added_count, .None, .None, .None
}
