package owlrl

import rdf "odin-rdf:rdf"
import rule "../rule"
import store "../store"
import term "../term"

// Property_Chain_Options bounds the dynamic prp-spo2 phase. max_path_states
// applies independently to each property-chain frontier; zero disables it.
Property_Chain_Options :: struct {
	max_rounds:      int,
	max_derivations: int,
	max_list_items:  int,
	max_path_states: int,
	generalized_heads: bool,
}

Property_Chain_Error_Code :: enum {
	None,
	Invalid_Option,
	Rule_Error,
	List_Error,
	Chain_Too_Short,
	Invalid_Chain_Property,
	Path_State_Limit,
	Out_Of_Memory,
	Store_Error,
}

Property_Chain_Result :: struct {
	error:          Property_Chain_Error_Code,
	rule_error:     rule.Error_Code,
	list_error:     List_Error_Code,
	store_error:    store.Error_Code,
	rounds:         int,
	inferred_facts: int,
}

@(private) Path_State :: struct {
	start, endpoint: term.Term_ID,
	supports:        [dynamic]store.Fact_ID,
}

@(private) clear_path_states :: proc(items: ^[dynamic]Path_State) {
	for item in items^ do delete(item.supports)
	clear(items)
}

@(private) destroy_path_states :: proc(items: ^[dynamic]Path_State) {
	clear_path_states(items)
	delete(items^)
}

// append_path_state retains only the first fact path for each start/endpoint
// pair, matching the store's first-support provenance convention.
@(private) append_path_state :: proc(items: ^[dynamic]Path_State, start, endpoint: term.Term_ID, prefix: []store.Fact_ID, fact_id: store.Fact_ID, max_states: int) -> Property_Chain_Error_Code {
	for item in items^ do if item.start == start && item.endpoint == endpoint do return .None
	if max_states != 0 && len(items^) >= max_states do return .Path_State_Limit
	supports := make([dynamic]store.Fact_ID, 0, len(prefix) + 1)
	for support in prefix {
		_, append_error := append(&supports, support)
		if append_error != nil { delete(supports); return .Out_Of_Memory }
	}
	_, append_error := append(&supports, fact_id)
	if append_error != nil { delete(supports); return .Out_Of_Memory }
	_, append_error = append(items, Path_State{start = start, endpoint = endpoint, supports = supports})
	if append_error != nil { delete(supports); return .Out_Of_Memory }
	return .None
}

@(private) add_property_chain_fact :: proc(profile: ^Profile, target: ^store.Store, subject, predicate, object: term.Term_ID, remaining: int, added_count: ^int, generalized_heads: bool, provenance: ^Closure_Provenance = nil, declaration_id: store.Fact_ID = store.INVALID_FACT_ID, list: ^List = nil, supports: []store.Fact_ID = nil) -> (Property_Chain_Error_Code, store.Error_Code) {
	if remaining >= 0 && added_count^ >= remaining do return .Rule_Error, .None
	subject_term, subject_ok := store.get_term(target, subject)
	predicate_term, predicate_ok := store.get_term(target, predicate)
	object_term, object_ok := store.get_term(target, object)
	if !subject_ok || !predicate_ok || !object_ok do return .Store_Error, .Invalid_Fact
	if !generalized_heads && rdf.validate_triple_structure({subject_term, predicate_term, object_term}) != .None do return .None, .None
	fact := store.Fact{subject = subject, predicate = predicate, object = object}
	if store.contains(target, fact) do return .None, .None
	added, insert_error := store.insert(target, fact, .Inferred)
	if insert_error != .None do return .Store_Error, insert_error
	if added {
		added_count^ += 1
		if provenance != nil {
			fact_id := store.id_for_fact(target, fact)
			if fact_id == store.INVALID_FACT_ID || declaration_id == store.INVALID_FACT_ID || list == nil || !append_list_derivation(provenance, fact_id, OWL_RL_PRP_SPO2, declaration_id, list, supports) do return .Out_Of_Memory, .Out_Of_Memory
		}
	}
	return .None, .None
}

// remaining is -1 when the global derivation limit is disabled.
@(private) emit_property_chains :: proc(profile: ^Profile, target: ^store.Store, options: Property_Chain_Options, remaining: int, provenance: ^Closure_Provenance = nil) -> (added_count: int, error: Property_Chain_Error_Code, list_error: List_Error_Code, store_error: store.Error_Code) {
	list: List
	init_list(&list)
	defer destroy_list(&list)
	frontier := make([dynamic]Path_State)
	defer destroy_path_states(&frontier)
	next_frontier := make([dynamic]Path_State)
	defer destroy_path_states(&next_frontier)
	for declaration_index in 0..<store.fact_count(target) {
		declaration_id, declaration, _, found := store.fact_at(target, declaration_index)
		if !found do return added_count, .Store_Error, .None, .Invalid_Fact
		if declaration.predicate != profile.terms.property_chain_axiom do continue
		if list_error = read_list(profile, target, declaration.object, &list, {max_items = options.max_list_items, generalized_heads = options.generalized_heads}); list_error != .None do return added_count, .List_Error, list_error, .None
		if list_count(&list) < 2 do return added_count, .Chain_Too_Short, .None, .None
		for item_index in 0..<list_count(&list) {
			property, _ := list_item_at(&list, item_index)
			property_term, property_ok := store.get_term(target, property)
			if !property_ok do return added_count, .Store_Error, .None, .Invalid_Fact
			if !options.generalized_heads && property_term.kind != .IRI do return added_count, .Invalid_Chain_Property, .None, .None
		}
		clear_path_states(&frontier)
		first_property, _ := list_item_at(&list, 0)
		for fact_index in 0..<store.fact_count(target) {
			fact_id, fact, _, fact_found := store.fact_at(target, fact_index)
			if !fact_found do return added_count, .Store_Error, .None, .Invalid_Fact
			if fact.predicate != first_property do continue
			if state_error := append_path_state(&frontier, fact.subject, fact.object, nil, fact_id, options.max_path_states); state_error != .None do return added_count, state_error, .None, .None
		}
		for property_index in 1..<list_count(&list) {
			clear_path_states(&next_frontier)
			property, _ := list_item_at(&list, property_index)
			for state in frontier {
				for fact_index in 0..<store.fact_count(target) {
					fact_id, fact, _, fact_found := store.fact_at(target, fact_index)
					if !fact_found do return added_count, .Store_Error, .None, .Invalid_Fact
					if fact.subject != state.endpoint || fact.predicate != property do continue
					if state_error := append_path_state(&next_frontier, state.start, fact.object, state.supports[:], fact_id, options.max_path_states); state_error != .None do return added_count, state_error, .None, .None
				}
			}
			frontier, next_frontier = next_frontier, frontier
			if len(frontier) == 0 do break
		}
		if len(frontier) == 0 do continue
		for state in frontier {
			phase_error, insert_error := add_property_chain_fact(profile, target, state.start, declaration.subject, state.endpoint, remaining, &added_count, options.generalized_heads, provenance, declaration_id, &list, state.supports[:])
			if phase_error != .None do return added_count, phase_error, .None, insert_error
		}
	}
	return added_count, .None, .None, .None
}

// materialize_property_chains alternates static rules with
// owl:propertyChainAxiom expansion until joint fixpoint. Strict mode requires
// IRI predicates and RDF-triple conclusions; generalized_heads uses the W3C
// generalized-RDF form. All work is committed only after success.
materialize_property_chains :: proc(profile: ^Profile, target: ^store.Store, options: Property_Chain_Options = {}) -> Property_Chain_Result {
	result: Property_Chain_Result
	if options.max_rounds < 0 || options.max_derivations < 0 || options.max_list_items < 0 || options.max_path_states < 0 { result.error = .Invalid_Option; return result }
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
		dynamic_added, dynamic_error, list_error, store_error := emit_property_chains(profile, &work, options, remaining)
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
