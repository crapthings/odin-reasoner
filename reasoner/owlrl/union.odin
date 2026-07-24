package owlrl

import rdf "odin-rdf:rdf"
import rule "../rule"
import store "../store"
import term "../term"

Union_Options :: struct {
	max_rounds:      int,
	max_derivations: int,
	max_list_items:  int,
}

Union_Error_Code :: enum {
	None,
	Invalid_Option,
	Rule_Error,
	List_Error,
	Store_Error,
}

Union_Result :: struct {
	error:          Union_Error_Code,
	rule_error:     rule.Error_Code,
	list_error:     List_Error_Code,
	store_error:    store.Error_Code,
	rounds:         int,
	inferred_facts: int,
}

@(private) add_union_type :: proc(profile: ^Profile, target: ^store.Store, subject, class: term.Term_ID, remaining: int, added_count: ^int) -> (Union_Error_Code, store.Error_Code) {
	if remaining >= 0 && added_count^ >= remaining do return .Rule_Error, .None
	subject_term, subject_ok := store.get_term(target, subject)
	predicate_term, predicate_ok := store.get_term(target, profile.terms.rdf_type)
	class_term, class_ok := store.get_term(target, class)
	if !subject_ok || !predicate_ok || !class_ok do return .Store_Error, .Invalid_Fact
	if rdf.validate_triple_structure({subject_term, predicate_term, class_term}) != .None do return .None, .None
	fact := store.Fact{subject = subject, predicate = profile.terms.rdf_type, object = class}
	if store.contains(target, fact) do return .None, .None
	added, insert_error := store.insert(target, fact, .Inferred)
	if insert_error != .None do return .Store_Error, insert_error
	if added do added_count^ += 1
	return .None, .None
}

// remaining is -1 when the global derivation limit is disabled.
@(private) emit_union :: proc(profile: ^Profile, target: ^store.Store, options: Union_Options, remaining: int) -> (added_count: int, error: Union_Error_Code, list_error: List_Error_Code, store_error: store.Error_Code) {
	list: List
	init_list(&list)
	defer destroy_list(&list)
	for declaration_index in 0..<store.fact_count(target) {
		_, declaration, _, found := store.fact_at(target, declaration_index)
		if !found do return added_count, .Store_Error, .None, .Invalid_Fact
		if declaration.predicate != profile.terms.union_of do continue
		if list_error = read_list(profile, target, declaration.object, &list, {max_items = options.max_list_items}); list_error != .None do return added_count, .List_Error, list_error, .None
		// cls-uni: each member class entails the enclosing union class. An empty
		// list has no members, so this finite forward rule has no conclusions.
		for item_index in 0..<list_count(&list) {
			member_class, _ := list_item_at(&list, item_index)
			for candidate_index in 0..<store.fact_count(target) {
				_, candidate, _, candidate_found := store.fact_at(target, candidate_index)
				if !candidate_found do return added_count, .Store_Error, .None, .Invalid_Fact
				if candidate.predicate != profile.terms.rdf_type || candidate.object != member_class do continue
				phase_error, insert_error := add_union_type(profile, target, candidate.subject, declaration.subject, remaining, &added_count)
				if phase_error != .None do return added_count, phase_error, .None, insert_error
			}
		}
	}
	return added_count, .None, .None, .None
}

// materialize_union alternates static OWL/RDFS rules with the W3C cls-uni
// direction in a clone until joint fixpoint. A well-formed empty list is
// accepted and has no finite cls-uni conclusion; malformed lists and limits
// leave the caller's store unchanged.
materialize_union :: proc(profile: ^Profile, target: ^store.Store, options: Union_Options = {}) -> Union_Result {
	result: Union_Result
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
		static := rule.materialize(&temporary, &work, profile.rules[:], {max_derivations = static_limit})
		rule.destroy(&temporary)
		if static.error != .None { result.error = .Rule_Error; result.rule_error = static.error; result.store_error = static.store_error; return result }
		result.inferred_facts += static.inferred_facts
		remaining = -1
		if options.max_derivations != 0 do remaining = options.max_derivations - result.inferred_facts
		dynamic_added, dynamic_error, list_error, store_error := emit_union(profile, &work, options, remaining)
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
