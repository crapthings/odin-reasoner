package owlrl

import rdf "odin-rdf:rdf"
import rule "../rule"
import store "../store"
import term "../term"

// Generalized_Datatype_Options bounds the W3C datatype closure. The limit is
// shared by static generalized OWL rules and the dt-type2/dt-eq/dt-diff phase.
// A zero limit disables that bound.
Generalized_Datatype_Options :: struct {
	max_rounds:      int,
	max_derivations: int,
}

Generalized_Datatype_Error_Code :: enum {
	None,
	Invalid_Option,
	Rule_Error,
	Store_Error,
	Out_Of_Memory,
}

generalized_datatype_error_message :: proc(code: Generalized_Datatype_Error_Code) -> string {
	switch code {
	case .None:           return "no generalized datatype materialization error"
	case .Invalid_Option: return "generalized datatype limits must not be negative"
	case .Rule_Error:     return "generalized OWL rule materialization failed"
	case .Store_Error:    return "fact store rejected a generalized datatype fact"
	case .Out_Of_Memory:  return "out of memory while materializing generalized datatype facts"
	}
	return "unknown generalized datatype materialization error"
}

Generalized_Datatype_Result :: struct {
	error:          Generalized_Datatype_Error_Code,
	rule_error:     rule.Error_Code,
	store_error:    store.Error_Code,
	rounds:         int,
	inferred_facts: int,
}

@(private) datatype_remaining :: proc(limit, inferred: int) -> int {
	if limit == 0 do return -1
	return limit - inferred
}

@(private) add_generalized_datatype_fact :: proc(target: ^store.Store, fact: store.Fact, rule_id: rule.Rule_ID, remaining: int, added_count: ^int) -> (Generalized_Datatype_Error_Code, store.Error_Code) {
	if store.contains(target, fact) do return .None, .None
	if remaining >= 0 && added_count^ >= remaining do return .Rule_Error, .None
	added, store_error := store.insert(target, fact, .Inferred)
	if store_error != .None do return store_error == .Out_Of_Memory ? .Out_Of_Memory : .Store_Error, store_error
	if added do added_count^ += 1
	_ = rule_id // dynamic datatype provenance is introduced with the complete generalized provenance ledger.
	return .None, .None
}

@(private) literal_terms :: proc(target: ^store.Store, output: ^[dynamic]term.Term_ID) -> (bool, store.Error_Code) {
	clear(output)
	for index in 0..<store.term_count(target) {
		id, value, found := store.term_at(target, index)
		if !found do return false, .Invalid_Fact
		if value.kind != .Literal do continue
		_, append_error := append(output, id)
		if append_error != nil do return false, .Out_Of_Memory
	}
	return true, .None
}

// emit_datatype_entailments derives the three positive datatype directions
// that can be expressed as generalized facts. It only consumes exact Yes/Same/
// Different results from odin-rdf; Unknown is deliberately not an inference.
@(private) emit_datatype_entailments :: proc(profile: ^Profile, target: ^store.Store, remaining: int) -> (added_count: int, error: Generalized_Datatype_Error_Code, store_error: store.Error_Code) {
	literals := make([dynamic]term.Term_ID)
	defer delete(literals)
	if ok, terms_error := literal_terms(target, &literals); !ok do return 0, terms_error == .Out_Of_Memory ? .Out_Of_Memory : .Store_Error, terms_error

	for literal_id in literals {
		literal, literal_found := store.get_term(target, literal_id)
		if !literal_found do return added_count, .Store_Error, .Invalid_Fact
		for datatype_id in profile.terms.owl_rl_datatypes {
			datatype, datatype_found := store.get_term(target, datatype_id)
			if !datatype_found do return added_count, .Store_Error, .Invalid_Fact
			if rdf.owl_rl_literal_value_membership(literal, datatype.value) != .Yes do continue
			phase_error, insert_error := add_generalized_datatype_fact(target, {subject = literal_id, predicate = profile.terms.rdf_type, object = datatype_id}, OWL_RL_DT_TYPE2, remaining, &added_count)
			if phase_error != .None do return added_count, phase_error, insert_error
		}
	}

	for left_index in 0..<len(literals) {
		left_id := literals[left_index]
		left, left_found := store.get_term(target, left_id)
		if !left_found do return added_count, .Store_Error, .Invalid_Fact
		for right_index in left_index..<len(literals) {
			right_id := literals[right_index]
			right, right_found := store.get_term(target, right_id)
			if !right_found do return added_count, .Store_Error, .Invalid_Fact
			relation := rdf.owl_rl_literal_value_relation(left, right)
			if relation == .Unknown do continue
			if relation == .Same {
				phase_error, insert_error := add_generalized_datatype_fact(target, {subject = left_id, predicate = profile.terms.same_as, object = right_id}, OWL_RL_DT_EQ, remaining, &added_count)
				if phase_error != .None do return added_count, phase_error, insert_error
				continue
			}
			if left_id == right_id do continue
			phase_error, insert_error := add_generalized_datatype_fact(target, {subject = left_id, predicate = profile.terms.different_from, object = right_id}, OWL_RL_DT_DIFF, remaining, &added_count)
			if phase_error != .None do return added_count, phase_error, insert_error
			phase_error, insert_error = add_generalized_datatype_fact(target, {subject = right_id, predicate = profile.terms.different_from, object = left_id}, OWL_RL_DT_DIFF, remaining, &added_count)
			if phase_error != .None do return added_count, phase_error, insert_error
		}
	}
	return added_count, .None, .None
}

// materialize_generalized_datatypes reaches a transactional fixpoint across
// static generalized OWL rules and the currently exact W3C datatype positive
// rules: dt-type2, dt-eq, and dt-diff. It intentionally does not claim full
// datatype conformance while value pairs returning Unknown remain. dt-not-type
// is a false-rule consistency check and is added with the generalized report.
materialize_generalized_datatypes :: proc(profile: ^Profile, target: ^store.Store, options: Generalized_Datatype_Options = {}) -> Generalized_Datatype_Result {
	result: Generalized_Datatype_Result
	if options.max_rounds < 0 || options.max_derivations < 0 { result.error = .Invalid_Option; return result }
	if !profile.initialized { result.error = .Rule_Error; result.rule_error = .Invalid_Rule; return result }

	work: store.Store
	if clone_error := store.clone(target, &work); clone_error != .None {
		result.error = clone_error == .Out_Of_Memory ? .Out_Of_Memory : .Store_Error
		result.store_error = clone_error
		return result
	}
	defer store.destroy(&work)

	for {
		if options.max_rounds != 0 && result.rounds >= options.max_rounds { result.error = .Rule_Error; result.rule_error = .Max_Rounds; return result }
		remaining := datatype_remaining(options.max_derivations, result.inferred_facts)
		if remaining == 0 { result.error = .Rule_Error; result.rule_error = .Max_Derivations; return result }
		static_limit := 0
		if remaining > 0 do static_limit = remaining
		temporary: rule.Materializer
		rule.init(&temporary)
		static := rule.materialize(&temporary, &work, profile.rules[:], {max_derivations = static_limit, generalized_heads = true})
		rule.destroy(&temporary)
		if static.error != .None {
			result.error = static.error == .Out_Of_Memory ? .Out_Of_Memory : .Rule_Error
			result.rule_error = static.error
			result.store_error = static.store_error
			return result
		}
		result.inferred_facts += static.inferred_facts
		phase_added := static.inferred_facts

		remaining = datatype_remaining(options.max_derivations, result.inferred_facts)
		datatype_added, datatype_error, datatype_store_error := emit_datatype_entailments(profile, &work, remaining)
		if datatype_error != .None {
			result.error = datatype_error
			result.store_error = datatype_store_error
			if datatype_error == .Rule_Error do result.rule_error = .Max_Derivations
			return result
		}
		result.inferred_facts += datatype_added
		phase_added += datatype_added
		result.rounds += 1
		if phase_added == 0 do break
	}

	_, commit_error := store.commit_inferred(&work, target)
	if commit_error != .None {
		result.error = commit_error == .Out_Of_Memory ? .Out_Of_Memory : .Store_Error
		result.store_error = commit_error
		result.inferred_facts = 0
		result.rounds = 0
	}
	return result
}
