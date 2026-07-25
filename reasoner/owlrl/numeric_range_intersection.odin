package owlrl

import rdf "odin-rdf:rdf"
import store "../store"

@(private) Numeric_Range_Intersection_Error_Code :: enum {
	None,
	Rule_Error,
	Store_Error,
	Out_Of_Memory,
}

// emit_numeric_range_intersections derives rdfs:range T when two asserted or
// already-derived ranges A and B on the same property have a nonempty modeled
// integer intersection wholly contained in T. It intentionally declines empty
// intersections (where vacuous containment would create arbitrary ranges) and
// every datatype family without an exact integer interval model.
@(private) emit_numeric_range_intersections :: proc(profile: ^Profile, target: ^store.Store, remaining: int, generalized_heads: bool, provenance: ^Closure_Provenance = nil) -> (added_count: int, error: Numeric_Range_Intersection_Error_Code, store_error: store.Error_Code) {
	fact_limit := store.fact_count(target)
	for left_index in 0..<fact_limit {
		left_id, left, _, left_found := store.fact_at(target, left_index)
		if !left_found do return added_count, .Store_Error, .Invalid_Fact
		if left.predicate != profile.terms.range do continue
		left_range, left_range_found := store.get_term(target, left.object)
		if !left_range_found do return added_count, .Store_Error, .Invalid_Fact

		for right_index in left_index+1..<fact_limit {
			right_id, right, _, right_found := store.fact_at(target, right_index)
			if !right_found do return added_count, .Store_Error, .Invalid_Fact
			if right.predicate != profile.terms.range || right.subject != left.subject do continue
			right_range, right_range_found := store.get_term(target, right.object)
			if !right_range_found do return added_count, .Store_Error, .Invalid_Fact

			for target_datatype in profile.terms.owl_rl_datatypes {
				target_range, target_range_found := store.get_term(target, target_datatype)
				if !target_range_found do return added_count, .Store_Error, .Invalid_Fact
				if !rdf.owl_rl_integer_datatype_intersection_is_subset_of(left_range.value, right_range.value, target_range.value) do continue

				subject_term, subject_found := store.get_term(target, left.subject)
				predicate_term, predicate_found := store.get_term(target, profile.terms.range)
				if !subject_found || !predicate_found do return added_count, .Store_Error, .Invalid_Fact
				if !generalized_heads && rdf.validate_triple_structure({subject_term, predicate_term, target_range}) != .None do continue
				fact := store.Fact{subject = left.subject, predicate = profile.terms.range, object = target_datatype}
				if store.contains(target, fact) do continue
				if remaining >= 0 && added_count >= remaining do return added_count, .Rule_Error, .None
				added, insert_error := store.insert(target, fact, .Inferred)
				if insert_error != .None do return added_count, insert_error == .Out_Of_Memory ? .Out_Of_Memory : .Store_Error, insert_error
				if !added do continue
				added_count += 1
				if provenance != nil {
					fact_id := store.id_for_fact(target, fact)
					if fact_id == store.INVALID_FACT_ID || !append_closure_derivation(provenance, fact_id, OWL_RDF_NUMERIC_RANGE_INTERSECTION, []store.Fact_ID{left_id, right_id}) do return added_count, .Out_Of_Memory, .Out_Of_Memory
				}
			}
		}
	}
	return added_count, .None, .None
}
