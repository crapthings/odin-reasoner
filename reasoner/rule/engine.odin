// Package rule supplies the minimal safe rule IR and semi-naive materializer.
package rule

import rdf "odin-rdf:rdf"
import store "../store"
import term "../term"

// Variable_ID identifies a variable local to a rule. IDs start at one.
Variable_ID :: distinct u16
INVALID_VARIABLE_ID :: Variable_ID(0)

// Rule_ID is a stable caller-supplied identifier recorded in derivations.
Rule_ID :: distinct u32
INVALID_RULE_ID :: Rule_ID(0)

MAX_VARIABLES  :: 64
MAX_BODY_ATOMS :: 16
MAX_HEAD_ATOMS :: 16

// Slot is either a constant interned term or a rule-local variable.
Slot :: struct {
	term:        term.Term_ID,
	variable:    Variable_ID,
	is_variable: bool,
}

constant :: proc(value: term.Term_ID) -> Slot { return Slot{term = value} }
variable :: proc(value: Variable_ID) -> Slot { return Slot{variable = value, is_variable = true} }

// Triple_Template is used in both rule bodies and heads.
Triple_Template :: struct { subject, predicate, object: Slot }

// Rule is borrowed by materialize for the duration of its call. body and head
// must remain valid during that call; the materializer never retains them.
Rule :: struct {
	id:   Rule_ID,
	body: []Triple_Template,
	head: []Triple_Template,
}

// Options bounds one materialization. A zero limit disables it.
Options :: struct {
	max_rounds:      int,
	max_derivations: int,
}

Error_Code :: enum {
	None,
	Invalid_Option,
	Invalid_Rule,
	Max_Rounds,
	Max_Derivations,
	Store_Error,
	Out_Of_Memory,
}

error_message :: proc(code: Error_Code) -> string {
	switch code {
	case .None:            return "no error"
	case .Invalid_Option:  return "engine limits must not be negative"
	case .Invalid_Rule:    return "invalid rule"
	case .Max_Rounds:      return "materialization round limit reached"
	case .Max_Derivations: return "materialization derivation limit reached"
	case .Store_Error:     return "fact store rejected a materialization fact"
	case .Out_Of_Memory:   return "out of memory"
	}
	return "unknown error"
}

// Result is complete only when error is None. On any error the source store is
// unchanged and inferred_facts/rounds are zero, so no partial closure is
// exposed as a successful result. store_error adds exact admission context.
Result :: struct {
	error:          Error_Code,
	store_error:    store.Error_Code,
	rounds:         int,
	inferred_facts: int,
}

// Derivation_View borrows its support slice from Materializer. It remains valid
// until the next materialize call or materializer.destroy.
Derivation_View :: struct {
	fact_id:  store.Fact_ID,
	rule_id:  Rule_ID,
	supports: []store.Fact_ID,
}

@(private) Derivation :: struct {
	fact_id:  store.Fact_ID,
	rule_id:  Rule_ID,
	supports: [dynamic]store.Fact_ID,
}

// Materializer owns the first derivation for each fact from its latest
// successful call. It is mutable and not safe for concurrent calls.
Materializer :: struct { derivations: [dynamic]Derivation }

init :: proc(materializer: ^Materializer) {
	materializer^ = Materializer{derivations = make([dynamic]Derivation)}
}

@(private) clear_derivations :: proc(derivations: ^[dynamic]Derivation) {
	for derivation in derivations^ do delete(derivation.supports)
	clear(derivations)
}

destroy :: proc(materializer: ^Materializer) {
	clear_derivations(&materializer.derivations)
	delete(materializer.derivations)
	materializer^ = {}
}

derivation_count :: proc(materializer: ^Materializer) -> int { return len(materializer.derivations) }

// derivation_at returns the first support recorded for one inferred fact.
derivation_at :: proc(materializer: ^Materializer, index: int) -> (Derivation_View, bool) {
	if index < 0 || index >= len(materializer.derivations) do return {}, false
	derivation := materializer.derivations[index]
	return {fact_id = derivation.fact_id, rule_id = derivation.rule_id, supports = derivation.supports[:]}, true
}

@(private) Binding :: struct { values: [MAX_VARIABLES]term.Term_ID }

@(private) valid_slot :: proc(target: ^store.Store, slot: Slot) -> bool {
	if slot.is_variable do return slot.variable != INVALID_VARIABLE_ID && int(slot.variable) <= MAX_VARIABLES
	if slot.term == term.INVALID_TERM_ID do return false
	_, found := store.get_term(target, slot.term)
	return found
}

@(private) mark_slot_variable :: proc(seen: ^[MAX_VARIABLES]bool, slot: Slot) {
	if slot.is_variable do seen[int(slot.variable) - 1] = true
}

@(private) template_slots :: proc(template: Triple_Template) -> [3]Slot {
	return {template.subject, template.predicate, template.object}
}

@(private) validate_rules :: proc(target: ^store.Store, rules: []Rule) -> bool {
	for rule in rules {
		if rule.id == INVALID_RULE_ID || len(rule.body) == 0 || len(rule.body) > MAX_BODY_ATOMS || len(rule.head) == 0 || len(rule.head) > MAX_HEAD_ATOMS do return false
		bound: [MAX_VARIABLES]bool
		for atom in rule.body {
			for slot in template_slots(atom) {
				if !valid_slot(target, slot) do return false
				mark_slot_variable(&bound, slot)
			}
		}
		for atom in rule.head {
			for slot in template_slots(atom) {
				if !valid_slot(target, slot) do return false
				if slot.is_variable && !bound[int(slot.variable) - 1] do return false
			}
		}
	}
	return true
}

@(private) unify_slot :: proc(slot: Slot, value: term.Term_ID, binding: ^Binding) -> bool {
	if !slot.is_variable do return slot.term == value
	index := int(slot.variable) - 1
	if binding.values[index] == term.INVALID_TERM_ID {
		binding.values[index] = value
		return true
	}
	return binding.values[index] == value
}

@(private) unify_atom :: proc(atom: Triple_Template, fact: store.Fact, binding: ^Binding) -> bool {
	return unify_slot(atom.subject, fact.subject, binding) &&
		unify_slot(atom.predicate, fact.predicate, binding) &&
		unify_slot(atom.object, fact.object, binding)
}

@(private) pattern_for :: proc(atom: Triple_Template, binding: Binding) -> store.Pattern {
	result: store.Pattern
	if !atom.subject.is_variable {
		result.subject = atom.subject.term
	} else {
		result.subject = binding.values[int(atom.subject.variable) - 1]
	}
	if !atom.predicate.is_variable {
		result.predicate = atom.predicate.term
	} else {
		result.predicate = binding.values[int(atom.predicate.variable) - 1]
	}
	if !atom.object.is_variable {
		result.object = atom.object.term
	} else {
		result.object = binding.values[int(atom.object.variable) - 1]
	}
	return result
}

@(private) head_fact :: proc(atom: Triple_Template, binding: Binding) -> (store.Fact, bool) {
	result: store.Fact
	if atom.subject.is_variable {
		result.subject = binding.values[int(atom.subject.variable) - 1]
	} else {
		result.subject = atom.subject.term
	}
	if atom.predicate.is_variable {
		result.predicate = binding.values[int(atom.predicate.variable) - 1]
	} else {
		result.predicate = atom.predicate.term
	}
	if atom.object.is_variable {
		result.object = binding.values[int(atom.object.variable) - 1]
	} else {
		result.object = atom.object.term
	}
	return result, result.subject != term.INVALID_TERM_ID && result.predicate != term.INVALID_TERM_ID && result.object != term.INVALID_TERM_ID
}

// valid_rdf_head preserves the Phase 1 strict RDF-triple store boundary. A
// rule match that would make a literal subject has no serializable RDF-triple
// head and is therefore not materialized by this profile-neutral engine.
@(private) valid_rdf_head :: proc(target: ^store.Store, fact: store.Fact) -> bool {
	subject, subject_ok := store.get_term(target, fact.subject)
	predicate, predicate_ok := store.get_term(target, fact.predicate)
	object, object_ok := store.get_term(target, fact.object)
	if !subject_ok || !predicate_ok || !object_ok do return false
	return rdf.validate_triple_structure({subject, predicate, object}) == .None
}

@(private) Run_State :: struct {
	work:             ^store.Store,
	options:          Options,
	next_delta:       ^[dynamic]store.Fact_ID,
	derivations:      ^[dynamic]Derivation,
	derivation_count: int,
	error:            Error_Code,
	store_error:      store.Error_Code,
}

@(private) Join_State :: struct {
	run:      ^Run_State,
	rule:     ^Rule,
	driver:   int,
	binding:  Binding,
	supports: [MAX_BODY_ATOMS]store.Fact_ID,
}

@(private) Scan_State :: struct { parent: ^Join_State, position: int }

@(private) append_derivation :: proc(run: ^Run_State, fact_id: store.Fact_ID, rule_id: Rule_ID, supports: []store.Fact_ID) -> bool {
	owned := make([dynamic]store.Fact_ID, 0, len(supports))
	for support in supports {
		_, append_error := append(&owned, support)
		if append_error != nil { delete(owned); run.error = .Out_Of_Memory; return false }
	}
	_, append_error := append(run.derivations, Derivation{fact_id = fact_id, rule_id = rule_id, supports = owned})
	if append_error != nil { delete(owned); run.error = .Out_Of_Memory; return false }
	return true
}

@(private) emit_heads :: proc(state: ^Join_State) {
	if state.run.error != .None do return
	for atom in state.rule.head {
		fact, valid := head_fact(atom, state.binding)
		if !valid { state.run.error = .Invalid_Rule; return }
		if !valid_rdf_head(state.run.work, fact) do continue
		if store.contains(state.run.work, fact) do continue
		if state.run.options.max_derivations > 0 && state.run.derivation_count >= state.run.options.max_derivations {
			state.run.error = .Max_Derivations
			return
		}
		added, store_error := store.insert(state.run.work, fact, .Inferred)
		if store_error != .None {
			state.run.error = .Store_Error
			state.run.store_error = store_error
			return
		}
		if !added do continue
		fact_id := store.id_for_fact(state.run.work, fact)
		_, append_error := append(state.run.next_delta, fact_id)
		if append_error != nil { state.run.error = .Out_Of_Memory; return }
		if !append_derivation(state.run, fact_id, state.rule.id, state.supports[:len(state.rule.body)]) do return
		state.run.derivation_count += 1
	}
}

@(private) join_body :: proc(state: ^Join_State, position: int) {
	if state.run.error != .None do return
	if position == len(state.rule.body) { emit_heads(state); return }
	if position == state.driver { join_body(state, position + 1); return }
	atom := state.rule.body[position]
	scan_state := Scan_State{parent = state, position = position}
	result := store.match(state.run.work, pattern_for(atom, state.binding), join_sink, &scan_state)
	if result.error != .None {
		state.run.error = .Store_Error
		state.run.store_error = result.error
	}
}

@(private) join_sink :: proc(id: store.Fact_ID, fact: store.Fact, _: store.Origin, user_data: rawptr) -> bool {
	scan := cast(^Scan_State)user_data
	if scan.parent.run.error != .None do return false
	child := scan.parent^
	if !unify_atom(child.rule.body[scan.position], fact, &child.binding) do return true
	child.supports[scan.position] = id
	join_body(&child, scan.position + 1)
	return child.run.error == .None
}

@(private) clone_store :: proc(source, destination: ^store.Store) -> store.Error_Code {
	if error := store.init(destination, store.options(source)); error != .None do return error
	for index in 0..<store.term_count(source) {
		id, value, found := store.term_at(source, index)
		if !found { store.destroy(destination); return .Invalid_Fact }
		cloned_id, error := store.intern_term(destination, value)
		if error != .None || cloned_id != id { store.destroy(destination); return error }
	}
	for index in 0..<store.fact_count(source) {
		_, fact, origin, found := store.fact_at(source, index)
		if !found { store.destroy(destination); return .Invalid_Fact }
		added, error := store.insert(destination, fact, origin)
		if error != .None || !added { store.destroy(destination); return error }
	}
	return .None
}

@(private) cleanup_temporary :: proc(delta: ^[dynamic]store.Fact_ID, next_delta: ^[dynamic]store.Fact_ID, derivations: ^[dynamic]Derivation) {
	delete(delta^)
	delete(next_delta^)
	clear_derivations(derivations)
	delete(derivations^)
}

// materialize computes a semi-naive closure into a bounded working snapshot,
// then commits it only after fixpoint success. Each evaluation round requires a
// body atom to be from the previous delta. The caller retains ownership of the
// rules and store; materializer owns the successful first-support provenance.
materialize :: proc(materializer: ^Materializer, target: ^store.Store, rules: []Rule, options: Options = {}) -> Result {
	result: Result
	if options.max_rounds < 0 || options.max_derivations < 0 { result.error = .Invalid_Option; return result }
	if !validate_rules(target, rules) { result.error = .Invalid_Rule; return result }

	work: store.Store
	if store_error := clone_store(target, &work); store_error != .None {
		result.error = store_error == .Out_Of_Memory ? .Out_Of_Memory : .Store_Error
		result.store_error = store_error
		return result
	}
	defer store.destroy(&work)

	delta := make([dynamic]store.Fact_ID, 0, store.fact_count(&work))
	next_delta := make([dynamic]store.Fact_ID)
	temporary_derivations := make([dynamic]Derivation)
	defer cleanup_temporary(&delta, &next_delta, &temporary_derivations)
	for index in 0..<store.fact_count(&work) {
		_, append_error := append(&delta, store.Fact_ID(index + 1))
		if append_error != nil { result.error = .Out_Of_Memory; return result }
	}

	run := Run_State{work = &work, options = options, next_delta = &next_delta, derivations = &temporary_derivations}
	rounds := 0
	for len(delta) > 0 {
		if options.max_rounds > 0 && rounds >= options.max_rounds { result.error = .Max_Rounds; return result }
		for rule_index in 0..<len(rules) {
			rule := &rules[rule_index]
			for driver in 0..<len(rule.body) {
				for delta_id in delta {
					fact, found := store.fact_for(&work, delta_id)
					if !found { result.error = .Store_Error; result.store_error = .Invalid_Fact; return result }
					state := Join_State{run = &run, rule = rule, driver = driver}
					if unify_atom(rule.body[driver], fact, &state.binding) {
						state.supports[driver] = delta_id
						join_body(&state, 0)
					}
					if run.error != .None do break
				}
				if run.error != .None do break
			}
			if run.error != .None do break
		}
		if run.error != .None {
			result.error = run.error
			result.store_error = run.store_error
			return result
		}
		rounds += 1
		delete(delta)
		delta = next_delta
		next_delta = make([dynamic]store.Fact_ID)
		run.next_delta = &next_delta
	}

	initial_facts := store.fact_count(target)
	for index in initial_facts..<store.fact_count(&work) {
		id, _, _, found := store.fact_at(&work, index)
		if !found { result.error = .Store_Error; result.store_error = .Invalid_Fact; return result }
		triple, valid := store.triple_for(&work, id)
		if !valid { result.error = .Store_Error; result.store_error = .Invalid_Fact; return result }
		added, store_error := store.insert_triple(target, triple, .Inferred)
		if store_error != .None || !added {
			result.error = .Store_Error
			result.store_error = store_error
			return result
		}
	}
	clear_derivations(&materializer.derivations)
	delete(materializer.derivations)
	materializer.derivations = temporary_derivations
	temporary_derivations = nil
	result.rounds = rounds
	result.inferred_facts = run.derivation_count
	return result
}
