package owlrl

import rdf "odin-rdf:rdf"
import rule "../rule"
import store "../store"
import term "../term"

Intersection_Options :: struct {
	max_rounds:      int,
	max_derivations: int,
	max_list_items:  int,
	generalized_heads: bool,
}

Intersection_Error_Code :: enum {
	None,
	Invalid_Option,
	Rule_Error,
	List_Error,
	Empty_List,
	Store_Error,
}

Intersection_Result :: struct {
	error:          Intersection_Error_Code,
	rule_error:     rule.Error_Code,
	list_error:     List_Error_Code,
	store_error:    store.Error_Code,
	rounds:         int,
	inferred_facts: int,
}

@(private) add_intersection_type :: proc(profile: ^Profile, target: ^store.Store, subject, class: term.Term_ID, remaining: int, added_count: ^int, generalized_heads: bool, provenance: ^Closure_Provenance = nil, rule_id: rule.Rule_ID = rule.INVALID_RULE_ID, declaration_id: store.Fact_ID = store.INVALID_FACT_ID, list: ^List = nil, supports: []store.Fact_ID = nil) -> (Intersection_Error_Code, store.Error_Code) {
	if remaining >= 0 && added_count^ >= remaining do return .Rule_Error, .None
	subject_term, subject_ok := store.get_term(target, subject)
	predicate_term, predicate_ok := store.get_term(target, profile.terms.rdf_type)
	class_term, class_ok := store.get_term(target, class)
	if !subject_ok || !predicate_ok || !class_ok do return .Store_Error, .Invalid_Fact
	if !generalized_heads && rdf.validate_triple_structure({subject_term, predicate_term, class_term}) != .None do return .None, .None
	fact := store.Fact{subject = subject, predicate = profile.terms.rdf_type, object = class}
	if store.contains(target, fact) do return .None, .None
	added, insert_error := store.insert(target, fact, .Inferred)
	if insert_error != .None do return .Store_Error, insert_error
	if added {
		added_count^ += 1
		if provenance != nil {
			fact_id := store.id_for_fact(target, fact)
			if fact_id == store.INVALID_FACT_ID || list == nil || rule_id == rule.INVALID_RULE_ID || declaration_id == store.INVALID_FACT_ID || !append_list_derivation(provenance, fact_id, rule_id, declaration_id, list, supports) do return .Store_Error, .Out_Of_Memory
		}
	}
	return .None, .None
}

@(private) add_intersection_subclass :: proc(profile: ^Profile, target: ^store.Store, subclass, superclass: term.Term_ID, remaining: int, added_count: ^int, generalized_heads: bool, provenance: ^Closure_Provenance = nil, declaration_id: store.Fact_ID = store.INVALID_FACT_ID, list: ^List = nil) -> (Intersection_Error_Code, store.Error_Code) {
	if remaining >= 0 && added_count^ >= remaining do return .Rule_Error, .None
	subclass_term, subclass_ok := store.get_term(target, subclass)
	predicate_term, predicate_ok := store.get_term(target, profile.terms.subclass_of)
	superclass_term, superclass_ok := store.get_term(target, superclass)
	if !subclass_ok || !predicate_ok || !superclass_ok do return .Store_Error, .Invalid_Fact
	if !generalized_heads && rdf.validate_triple_structure({subclass_term, predicate_term, superclass_term}) != .None do return .None, .None
	fact := store.Fact{subject = subclass, predicate = profile.terms.subclass_of, object = superclass}
	if store.contains(target, fact) do return .None, .None
	added, insert_error := store.insert(target, fact, .Inferred)
	if insert_error != .None do return .Store_Error, insert_error
	if added {
		added_count^ += 1
		if provenance != nil {
			fact_id := store.id_for_fact(target, fact)
			if fact_id == store.INVALID_FACT_ID || list == nil || declaration_id == store.INVALID_FACT_ID || !append_list_derivation(provenance, fact_id, OWL_RL_SCM_INT, declaration_id, list, nil) do return .Store_Error, .Out_Of_Memory
		}
	}
	return .None, .None
}

// remaining is -1 when the global derivation limit is disabled.
@(private) emit_intersection :: proc(profile: ^Profile, target: ^store.Store, options: Intersection_Options, remaining: int, provenance: ^Closure_Provenance = nil) -> (added_count: int, error: Intersection_Error_Code, list_error: List_Error_Code, store_error: store.Error_Code) {
	list: List
	init_list(&list)
	defer destroy_list(&list)
	for declaration_index in 0..<store.fact_count(target) {
		declaration_id, declaration, _, found := store.fact_at(target, declaration_index)
		if !found do return added_count, .Store_Error, .None, .Invalid_Fact
		if declaration.predicate != profile.terms.intersection_of do continue
		if list_error = read_list(profile, target, declaration.object, &list, {max_items = options.max_list_items, generalized_heads = options.generalized_heads}); list_error != .None do return added_count, .List_Error, list_error, .None
		if list_count(&list) == 0 do return added_count, .Empty_List, .None, .None
		// scm-int: an intersection class is a subclass of every list member.
		for item_index in 0..<list_count(&list) {
			member_class, _ := list_item_at(&list, item_index)
			phase_error, insert_error := add_intersection_subclass(profile, target, declaration.subject, member_class, remaining, &added_count, options.generalized_heads, provenance, declaration_id, &list)
			if phase_error != .None do return added_count, phase_error, .None, insert_error
		}
		first_class, _ := list_item_at(&list, 0)
		// cls-int1: members of every listed class are members of the intersection.
		for candidate_index in 0..<store.fact_count(target) {
			candidate_id, candidate, _, candidate_found := store.fact_at(target, candidate_index)
			if !candidate_found do return added_count, .Store_Error, .None, .Invalid_Fact
			if candidate.predicate != profile.terms.rdf_type || candidate.object != first_class do continue
			all_members := true
			supports := make([dynamic]store.Fact_ID)
			_, append_error := append(&supports, candidate_id)
			if append_error != nil { delete(supports); return added_count, .Store_Error, .None, .Out_Of_Memory }
			for item_index in 1..<list_count(&list) {
				member_class, _ := list_item_at(&list, item_index)
				member_id := store.id_for_fact(target, {subject = candidate.subject, predicate = profile.terms.rdf_type, object = member_class})
				if member_id == store.INVALID_FACT_ID {
					all_members = false
					break
				}
				_, append_error = append(&supports, member_id)
				if append_error != nil { delete(supports); return added_count, .Store_Error, .None, .Out_Of_Memory }
			}
			if !all_members { delete(supports); continue }
			phase_error, insert_error := add_intersection_type(profile, target, candidate.subject, declaration.subject, remaining, &added_count, options.generalized_heads, provenance, OWL_RL_CLS_INT1, declaration_id, &list, supports[:])
			delete(supports)
			if phase_error != .None do return added_count, phase_error, .None, insert_error
		}
		// cls-int2: every member of the intersection is a member of each list item.
		for candidate_index in 0..<store.fact_count(target) {
			candidate_id, candidate, _, candidate_found := store.fact_at(target, candidate_index)
			if !candidate_found do return added_count, .Store_Error, .None, .Invalid_Fact
			if candidate.predicate != profile.terms.rdf_type || candidate.object != declaration.subject do continue
			for item_index in 0..<list_count(&list) {
				member_class, _ := list_item_at(&list, item_index)
				phase_error, insert_error := add_intersection_type(profile, target, candidate.subject, member_class, remaining, &added_count, options.generalized_heads, provenance, OWL_RL_CLS_INT2, declaration_id, &list, []store.Fact_ID{candidate_id})
				if phase_error != .None do return added_count, phase_error, .None, insert_error
			}
		}
	}
	return added_count, .None, .None, .None
}

// materialize_intersection alternates static rules with the two finite
// owl:intersectionOf directions in a clone until joint fixpoint. Empty lists
// are rejected explicitly because their OWL semantics would require owl:Thing
// handling that this bounded strict-RDF profile does not claim.
materialize_intersection :: proc(profile: ^Profile, target: ^store.Store, options: Intersection_Options = {}) -> Intersection_Result {
	result: Intersection_Result
	if options.max_rounds < 0 || options.max_derivations < 0 || options.max_list_items < 0 { result.error = .Invalid_Option; return result }
	if !profile.initialized { result.error = .Rule_Error; result.rule_error = .Invalid_Rule; return result }
	work: store.Store
	if clone_error := store.clone(target, &work); clone_error != .None { result.error = .Store_Error; result.store_error = clone_error; return result }
	defer store.destroy(&work)
	for {
		if options.max_rounds != 0 && result.rounds >= options.max_rounds { result.error = .Rule_Error; result.rule_error = .Max_Rounds; return result }
		remaining := -1
		if options.max_derivations != 0 {
			remaining = options.max_derivations - result.inferred_facts
			if remaining <= 0 { result.error = .Rule_Error; result.rule_error = .Max_Derivations; return result }
		}
		static_limit := 0
		if remaining >= 0 do static_limit = remaining
		temporary: rule.Materializer
		rule.init(&temporary)
		static := rule.materialize(&temporary, &work, profile.rules[:], {max_derivations = static_limit, generalized_heads = options.generalized_heads})
		rule.destroy(&temporary)
		if static.error != .None { result.error = .Rule_Error; result.rule_error = static.error; result.store_error = static.store_error; return result }
		result.inferred_facts += static.inferred_facts
		remaining = -1
		if options.max_derivations != 0 do remaining = options.max_derivations - result.inferred_facts
		dynamic_added, dynamic_error, list_error, store_error := emit_intersection(profile, &work, options, remaining)
		if dynamic_error != .None {
			result.error = dynamic_error
			result.list_error = list_error
			result.store_error = store_error
			if dynamic_error == .Rule_Error do result.rule_error = .Max_Derivations
			return result
		}
		result.inferred_facts += dynamic_added
		result.rounds += 1
		if static.inferred_facts == 0 && dynamic_added == 0 do break
	}
	_, commit_error := store.commit_inferred(&work, target)
	if commit_error != .None { result.error = .Store_Error; result.store_error = commit_error; result.inferred_facts = 0; result.rounds = 0; return result }
	return result
}
