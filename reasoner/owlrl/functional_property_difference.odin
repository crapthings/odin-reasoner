package owlrl

import rdf "odin-rdf:rdf"
import rule "../rule"
import store "../store"
import term "../term"

Functional_Property_Difference_Error_Code :: enum {
	None,
	Rule_Error,
	Out_Of_Memory,
	Store_Error,
}

@(private) add_functional_property_difference :: proc(profile: ^Profile, target: ^store.Store, subject, object: term.Term_ID, remaining: int, added_count: ^int, generalized_heads: bool, provenance: ^Closure_Provenance, rule_id: rule.Rule_ID, declaration_id, left_id, right_id, difference_id: store.Fact_ID) -> (Functional_Property_Difference_Error_Code, store.Error_Code) {
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
	fact_id := store.id_for_fact(target, fact)
	if fact_id == store.INVALID_FACT_ID || !append_closure_derivation(provenance, fact_id, rule_id, []store.Fact_ID{declaration_id, left_id, right_id, difference_id}) do return .Out_Of_Memory, .Out_Of_Memory
	return .None, .None
}

// emit_functional_property_differences preserves explicit inequality through
// functional and inverse-functional properties. If two outer resources were
// equal, the associated property assertions would force equality of a pair
// already known to be owl:differentFrom.
@(private) emit_functional_property_differences :: proc(profile: ^Profile, target: ^store.Store, remaining: int, generalized_heads: bool, provenance: ^Closure_Provenance) -> (added_count: int, error: Functional_Property_Difference_Error_Code, store_error: store.Error_Code) {
	fact_limit := store.fact_count(target)
	for declaration_index in 0..<fact_limit {
		declaration_id, declaration, _, declaration_found := store.fact_at(target, declaration_index)
		if !declaration_found do return added_count, .Store_Error, .Invalid_Fact
		if declaration.predicate != profile.terms.rdf_type do continue
		is_functional := declaration.object == profile.terms.functional_property
		is_inverse_functional := declaration.object == profile.terms.inverse_functional_property
		if !is_functional && !is_inverse_functional do continue
		for left_index in 0..<fact_limit {
			left_id, left, _, left_found := store.fact_at(target, left_index)
			if !left_found do return added_count, .Store_Error, .Invalid_Fact
			if left.predicate != declaration.subject do continue
			for right_index in 0..<fact_limit {
				right_id, right, _, right_found := store.fact_at(target, right_index)
				if !right_found do return added_count, .Store_Error, .Invalid_Fact
				if right.predicate != declaration.subject do continue
				if is_functional {
					difference_id := store.id_for_fact(target, {subject = left.object, predicate = profile.terms.different_from, object = right.object})
					if difference_id == store.INVALID_FACT_ID do continue
					phase_error, phase_store_error := add_functional_property_difference(profile, target, left.subject, right.subject, remaining, &added_count, generalized_heads, provenance, OWL_RDF_FUNCTIONAL_PROPERTY_DIFFERENCE, declaration_id, left_id, right_id, difference_id)
					if phase_error != .None do return added_count, phase_error, phase_store_error
				} else {
					difference_id := store.id_for_fact(target, {subject = left.subject, predicate = profile.terms.different_from, object = right.subject})
					if difference_id == store.INVALID_FACT_ID do continue
					phase_error, phase_store_error := add_functional_property_difference(profile, target, left.object, right.object, remaining, &added_count, generalized_heads, provenance, OWL_RDF_INVERSE_FUNCTIONAL_PROPERTY_DIFFERENCE, declaration_id, left_id, right_id, difference_id)
					if phase_error != .None do return added_count, phase_error, phase_store_error
				}
			}
		}
	}
	return added_count, .None, .None
}
