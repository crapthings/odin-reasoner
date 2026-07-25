package owlrl

import rule "../rule"
import store "../store"

// Materialize_All_Options bounds one complete supported OWL RL closure. The
// derivation and round bounds apply across static rules and every dynamic RDF
// list phase. max_list_items applies to each decoded collection; zero disables
// an individual bound. max_path_states applies to one property-chain frontier.
// generalized_heads enables W3C generalized-RDF conclusions throughout the
// static and dynamic phases; strict RDF remains the default.
Materialize_All_Options :: struct {
	max_rounds:      int,
	max_derivations: int,
	max_list_items:  int,
	max_path_states: int,
	generalized_heads: bool,
}

Materialize_All_Error_Code :: enum {
	None,
	Invalid_Option,
	Rule_Error,
	List_Error,
	Empty_Intersection,
	Chain_Too_Short,
	Invalid_Chain_Property,
	Path_State_Limit,
	Out_Of_Memory,
	Store_Error,
}

materialize_all_error_message :: proc(code: Materialize_All_Error_Code) -> string {
	switch code {
	case .None:                   return "no error"
	case .Invalid_Option:         return "complete OWL RL limits must not be negative"
	case .Rule_Error:             return "static or dynamic rule materialization failed"
	case .List_Error:             return "malformed RDF list in an OWL RL entailment rule"
	case .Empty_Intersection:     return "owl:intersectionOf must not have an empty list in this profile"
	case .Chain_Too_Short:        return "owl:propertyChainAxiom needs at least two properties"
	case .Invalid_Chain_Property: return "owl:propertyChainAxiom members must be IRIs"
	case .Path_State_Limit:       return "property-chain path frontier limit reached"
	case .Out_Of_Memory:          return "out of memory while materializing OWL RL closure"
	case .Store_Error:            return "fact store rejected an OWL RL materialization fact"
	}
	return "unknown complete OWL RL materialization error"
}

// Materialize_All_Result is complete only when error is None. On every error
// the caller's store is unchanged; inferred_facts and rounds then describe the
// work completed in the private snapshot before the failure was discovered.
Materialize_All_Result :: struct {
	error:          Materialize_All_Error_Code,
	rule_error:     rule.Error_Code,
	list_error:     List_Error_Code,
	store_error:    store.Error_Code,
	rounds:         int,
	inferred_facts: int,
}

@(private) remaining_derivations :: proc(max_derivations, inferred_facts: int) -> int {
	if max_derivations == 0 do return -1
	return max_derivations - inferred_facts
}

// materialize_all reaches one transactional fixpoint across the profile's
// static RDFS/OWL rules and its supported numeric range-intersection, oneOf,
// intersectionOf, unionOf, propertyChainAxiom, and hasKey phases. The existing focused materializers remain useful
// for isolating one rule family; this is the complete supported closure entry
// point. It also stages first-support closure provenance for static and list
// facts; focused dynamic materializers retain their smaller origin-only API.
materialize_all :: proc(profile: ^Profile, target: ^store.Store, options: Materialize_All_Options = {}) -> Materialize_All_Result {
	result: Materialize_All_Result
	if options.max_rounds < 0 || options.max_derivations < 0 || options.max_list_items < 0 || options.max_path_states < 0 {
		result.error = .Invalid_Option
		return result
	}
	if !profile.initialized {
		result.error = .Rule_Error
		result.rule_error = .Invalid_Rule
		return result
	}

	work: store.Store
	if clone_error := store.clone(target, &work); clone_error != .None {
		result.error = clone_error == .Out_Of_Memory ? .Out_Of_Memory : .Store_Error
		result.store_error = clone_error
		return result
	}
	defer store.destroy(&work)
	staged_provenance: Closure_Provenance
	init_closure_provenance(&staged_provenance)
	defer destroy_closure_provenance(&staged_provenance)

	one_of_options := One_Of_Options{max_list_items = options.max_list_items, generalized_heads = options.generalized_heads}
	intersection_options := Intersection_Options{max_list_items = options.max_list_items, generalized_heads = options.generalized_heads}
	union_options := Union_Options{max_list_items = options.max_list_items, generalized_heads = options.generalized_heads}
	chain_options := Property_Chain_Options{max_list_items = options.max_list_items, max_path_states = options.max_path_states, generalized_heads = options.generalized_heads}

	for {
		if options.max_rounds != 0 && result.rounds >= options.max_rounds {
			result.error = .Rule_Error
			result.rule_error = .Max_Rounds
			return result
		}
		remaining := remaining_derivations(options.max_derivations, result.inferred_facts)
		if remaining == 0 {
			result.error = .Rule_Error
			result.rule_error = .Max_Derivations
			return result
		}

		static_limit := 0
		if remaining > 0 do static_limit = remaining
		temporary: rule.Materializer
		rule.init(&temporary)
		static := rule.materialize(&temporary, &work, profile.rules[:], {max_derivations = static_limit, generalized_heads = options.generalized_heads})
		if static.error != .None {
			rule.destroy(&temporary)
			result.error = static.error == .Out_Of_Memory ? .Out_Of_Memory : .Rule_Error
			result.rule_error = static.error
			result.store_error = static.store_error
			return result
		}
		if !append_static_derivations(&staged_provenance, &temporary) {
			rule.destroy(&temporary)
			result.error = .Out_Of_Memory
			return result
		}
		rule.destroy(&temporary)
		result.inferred_facts += static.inferred_facts
		phase_added := static.inferred_facts

		remaining = remaining_derivations(options.max_derivations, result.inferred_facts)
		numeric_range_added, numeric_range_error, numeric_range_store_error := emit_numeric_range_intersections(profile, &work, remaining, options.generalized_heads, &staged_provenance)
		if numeric_range_error != .None {
			if numeric_range_error == .Rule_Error {
				result.error = .Rule_Error
				result.rule_error = .Max_Derivations
			} else {
				result.error = numeric_range_error == .Out_Of_Memory ? .Out_Of_Memory : .Store_Error
				result.store_error = numeric_range_store_error
			}
			return result
		}
		result.inferred_facts += numeric_range_added
		phase_added += numeric_range_added

		remaining = remaining_derivations(options.max_derivations, result.inferred_facts)
		one_of_added, one_of_error, one_of_list_error, one_of_store_error := emit_one_of(profile, &work, one_of_options, remaining, &staged_provenance)
		if one_of_error != .None {
			if one_of_error == .Rule_Error {
				result.error = .Rule_Error
				result.rule_error = .Max_Derivations
			} else if one_of_error == .List_Error {
				result.error = .List_Error
				result.list_error = one_of_list_error
			} else {
				result.error = one_of_store_error == .Out_Of_Memory ? .Out_Of_Memory : .Store_Error
				result.store_error = one_of_store_error
			}
			return result
		}
		result.inferred_facts += one_of_added
		phase_added += one_of_added

		remaining = remaining_derivations(options.max_derivations, result.inferred_facts)
		intersection_added, intersection_error, intersection_list_error, intersection_store_error := emit_intersection(profile, &work, intersection_options, remaining, &staged_provenance)
		if intersection_error != .None {
			if intersection_error == .Rule_Error {
				result.error = .Rule_Error
				result.rule_error = .Max_Derivations
			} else if intersection_error == .List_Error {
				result.error = .List_Error
				result.list_error = intersection_list_error
			} else if intersection_error == .Empty_List {
				result.error = .Empty_Intersection
			} else {
				result.error = intersection_store_error == .Out_Of_Memory ? .Out_Of_Memory : .Store_Error
				result.store_error = intersection_store_error
			}
			return result
		}
		result.inferred_facts += intersection_added
		phase_added += intersection_added

		remaining = remaining_derivations(options.max_derivations, result.inferred_facts)
		union_added, union_error, union_list_error, union_store_error := emit_union(profile, &work, union_options, remaining, &staged_provenance)
		if union_error != .None {
			if union_error == .Rule_Error {
				result.error = .Rule_Error
				result.rule_error = .Max_Derivations
			} else if union_error == .List_Error {
				result.error = .List_Error
				result.list_error = union_list_error
			} else {
				result.error = union_store_error == .Out_Of_Memory ? .Out_Of_Memory : .Store_Error
				result.store_error = union_store_error
			}
			return result
		}
		result.inferred_facts += union_added
		phase_added += union_added

		remaining = remaining_derivations(options.max_derivations, result.inferred_facts)
		chain_added, chain_error, chain_list_error, chain_store_error := emit_property_chains(profile, &work, chain_options, remaining, &staged_provenance)
		if chain_error != .None {
			if chain_error == .Rule_Error {
				result.error = .Rule_Error
				result.rule_error = .Max_Derivations
			} else if chain_error == .List_Error {
				result.error = .List_Error
				result.list_error = chain_list_error
			} else if chain_error == .Chain_Too_Short {
				result.error = .Chain_Too_Short
			} else if chain_error == .Invalid_Chain_Property {
				result.error = .Invalid_Chain_Property
			} else if chain_error == .Path_State_Limit {
				result.error = .Path_State_Limit
			} else if chain_error == .Out_Of_Memory {
				result.error = .Out_Of_Memory
			} else {
				result.error = .Store_Error
				result.store_error = chain_store_error
			}
			return result
		}
		result.inferred_facts += chain_added
		phase_added += chain_added

		remaining = remaining_derivations(options.max_derivations, result.inferred_facts)
		key_added, key_error, key_list_error, key_store_error := emit_has_keys(profile, &work, options.max_list_items, remaining, options.generalized_heads, &staged_provenance)
		if key_error != .None {
			if key_error == .Rule_Error {
				result.error = .Rule_Error
				result.rule_error = .Max_Derivations
			} else if key_error == .List_Error {
				result.error = .List_Error
				result.list_error = key_list_error
			} else if key_error == .Out_Of_Memory {
				result.error = .Out_Of_Memory
			} else {
				result.error = .Store_Error
				result.store_error = key_store_error
			}
			return result
		}
		result.inferred_facts += key_added
		phase_added += key_added

		result.rounds += 1
		if phase_added == 0 do break
	}

	_, commit_error := store.commit_inferred(&work, target)
	if commit_error != .None {
		result.error = commit_error == .Out_Of_Memory ? .Out_Of_Memory : .Store_Error
		result.store_error = commit_error
		result.inferred_facts = 0
		result.rounds = 0
		return result
	}
	// rule.Materializer cannot represent the complete multi-phase provenance
	// ledger, which lives above. Do not expose stale focused static derivations.
	rule.destroy(&profile.materializer)
	rule.init(&profile.materializer)
	destroy_closure_provenance(&profile.closure_provenance)
	profile.closure_provenance = staged_provenance
	staged_provenance = {}
	return result
}
