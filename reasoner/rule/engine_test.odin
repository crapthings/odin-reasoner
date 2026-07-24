package rule

import "core:testing"
import rdf "odin-rdf:rdf"
import store "../store"
import term "../term"

@(private) ids_for :: proc(target: ^store.Store) -> [7]term.Term_ID {
	return {
		term.id_for(&target.dictionary, rdf.iri("urn:a")),
		term.id_for(&target.dictionary, rdf.iri("urn:b")),
		term.id_for(&target.dictionary, rdf.iri("urn:c")),
		term.id_for(&target.dictionary, rdf.iri("urn:d")),
		term.id_for(&target.dictionary, rdf.iri("urn:p")),
		term.id_for(&target.dictionary, rdf.iri("urn:q")),
		term.id_for(&target.dictionary, rdf.iri("urn:r")),
	}
}

@(private) seed_chain :: proc(t: ^testing.T, target: ^store.Store) {
	testing.expect_value(t, store.init(target), store.Error_Code.None)
	triples := []rdf.Triple{
		rdf.Triple{rdf.iri("urn:a"), rdf.iri("urn:p"), rdf.iri("urn:b")},
		rdf.Triple{rdf.iri("urn:b"), rdf.iri("urn:p"), rdf.iri("urn:c")},
		rdf.Triple{rdf.iri("urn:c"), rdf.iri("urn:p"), rdf.iri("urn:d")},
	}
	for triple in triples {
		added, error := store.insert_triple(target, triple)
		testing.expect(t, added)
		testing.expect_value(t, error, store.Error_Code.None)
	}
}

@(private) Transitive_Rule :: struct {
	body: [2]Triple_Template,
	head: [1]Triple_Template,
}

@(private) init_transitive_rule :: proc(definition: ^Transitive_Rule, p: term.Term_ID) {
	x, y, z := Variable_ID(1), Variable_ID(2), Variable_ID(3)
	definition.body = {
		{variable(x), constant(p), variable(y)},
		{variable(y), constant(p), variable(z)},
	}
	definition.head = {{variable(x), constant(p), variable(z)}}
}

@(private) transitive_rule :: proc(definition: ^Transitive_Rule) -> Rule {
	return {id = Rule_ID(100), body = definition.body[:], head = definition.head[:]}
}

@(private) contains_triple :: proc(target: ^store.Store, triple: rdf.Triple) -> bool {
	fact := store.Fact{
		subject = term.id_for(&target.dictionary, triple.subject),
		predicate = term.id_for(&target.dictionary, triple.predicate),
		object = term.id_for(&target.dictionary, triple.object),
	}
	if fact.subject == term.INVALID_TERM_ID || fact.predicate == term.INVALID_TERM_ID || fact.object == term.INVALID_TERM_ID do return false
	return store.contains(target, fact)
}

@(test)
test_binding_compatibility_and_unification :: proc(t: ^testing.T) {
	binding: Binding
	variable_slot := variable(Variable_ID(1))
	testing.expect(t, unify_slot(variable_slot, term.Term_ID(4), &binding))
	testing.expect(t, unify_slot(variable_slot, term.Term_ID(4), &binding))
	testing.expect(t, !unify_slot(variable_slot, term.Term_ID(5), &binding))
	testing.expect(t, unify_slot(constant(term.Term_ID(7)), term.Term_ID(7), &binding))
	testing.expect(t, !unify_slot(constant(term.Term_ID(7)), term.Term_ID(8), &binding))
}

@(test)
test_recursive_closure_terminates_and_records_first_support :: proc(t: ^testing.T) {
	target: store.Store
	seed_chain(t, &target)
	defer store.destroy(&target)
	ids := ids_for(&target)
	definition: Transitive_Rule
	init_transitive_rule(&definition, ids[4])
	rule := transitive_rule(&definition)
	materializer: Materializer
	init(&materializer)
	defer destroy(&materializer)

	result := materialize(&materializer, &target, []Rule{rule})
	testing.expect_value(t, result.error, Error_Code.None)
	testing.expect_value(t, result.inferred_facts, 3)
	testing.expect_value(t, store.fact_count(&target), 6)
	testing.expect(t, contains_triple(&target, {rdf.iri("urn:a"), rdf.iri("urn:p"), rdf.iri("urn:c")}))
	testing.expect(t, contains_triple(&target, {rdf.iri("urn:b"), rdf.iri("urn:p"), rdf.iri("urn:d")}))
	testing.expect(t, contains_triple(&target, {rdf.iri("urn:a"), rdf.iri("urn:p"), rdf.iri("urn:d")}))
	testing.expect_value(t, derivation_count(&materializer), 3)
	derivation, found := derivation_at(&materializer, 0)
	testing.expect(t, found)
	testing.expect_value(t, derivation.rule_id, Rule_ID(100))
	testing.expect_value(t, len(derivation.supports), 2)

	second := materialize(&materializer, &target, []Rule{rule})
	testing.expect_value(t, second.error, Error_Code.None)
	testing.expect_value(t, second.inferred_facts, 0)
	testing.expect_value(t, store.fact_count(&target), 6)
}

@(test)
test_multiple_paths_dedupe_and_keep_first_rule_provenance :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	_, inserted := store.insert_triple(&target, {rdf.iri("urn:a"), rdf.iri("urn:p"), rdf.iri("urn:b")})
	testing.expect_value(t, inserted, store.Error_Code.None)
	_, q_error := store.intern_term(&target, rdf.iri("urn:q"))
	testing.expect_value(t, q_error, store.Error_Code.None)
	ids := ids_for(&target)
	x, y := Variable_ID(1), Variable_ID(2)
	body := []Triple_Template{{variable(x), constant(ids[4]), variable(y)}}
	head := []Triple_Template{{variable(x), constant(ids[5]), variable(y)}}
	rules := []Rule{{id = Rule_ID(1), body = body, head = head}, {id = Rule_ID(2), body = body, head = head}}
	materializer: Materializer
	init(&materializer)
	defer destroy(&materializer)

	result := materialize(&materializer, &target, rules)
	testing.expect_value(t, result.error, Error_Code.None)
	testing.expect_value(t, result.inferred_facts, 1)
	testing.expect_value(t, store.fact_count(&target), 2)
	derivation, found := derivation_at(&materializer, 0)
	testing.expect(t, found)
	testing.expect_value(t, derivation.rule_id, Rule_ID(1))
}

@(test)
test_one_binding_can_emit_multiple_head_templates :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	_, input_error := store.insert_triple(&target, {rdf.iri("urn:a"), rdf.iri("urn:p"), rdf.iri("urn:b")})
	testing.expect_value(t, input_error, store.Error_Code.None)
	_, q_error := store.intern_term(&target, rdf.iri("urn:q"))
	_, r_error := store.intern_term(&target, rdf.iri("urn:r"))
	testing.expect_value(t, q_error, store.Error_Code.None)
	testing.expect_value(t, r_error, store.Error_Code.None)
	ids := ids_for(&target)
	x, y := Variable_ID(1), Variable_ID(2)
	body := []Triple_Template{{variable(x), constant(ids[4]), variable(y)}}
	head := []Triple_Template{
		{variable(x), constant(ids[5]), variable(y)},
		{variable(x), constant(ids[6]), variable(y)},
	}
	rule := Rule{id = Rule_ID(3), body = body, head = head}
	materializer: Materializer
	init(&materializer)
	defer destroy(&materializer)
	result := materialize(&materializer, &target, []Rule{rule})
	testing.expect_value(t, result.error, Error_Code.None)
	testing.expect_value(t, result.inferred_facts, 2)
	testing.expect_value(t, store.fact_count(&target), 3)
	testing.expect_value(t, derivation_count(&materializer), 2)
}

@(private) Naive_State :: struct {
	target:  ^store.Store,
	rule:    ^Rule,
	binding: Binding,
	changed: ^bool,
}

@(private) Naive_Scan :: struct { parent: ^Naive_State, position: int }

@(private) naive_join :: proc(state: ^Naive_State, position: int) {
	if position == len(state.rule.body) {
		for atom in state.rule.head {
			fact, valid := head_fact(atom, state.binding)
			if !valid do return
			added, error := store.insert(state.target, fact, .Inferred)
			if error == .None && added do state.changed^ = true
		}
		return
	}
	scan := Naive_Scan{parent = state, position = position}
	_ = store.match(state.target, pattern_for(state.rule.body[position], state.binding), naive_sink, &scan)
}

@(private) naive_sink :: proc(_: store.Fact_ID, fact: store.Fact, _: store.Origin, user_data: rawptr) -> bool {
	scan := cast(^Naive_Scan)user_data
	child := scan.parent^
	if !unify_atom(child.rule.body[scan.position], fact, &child.binding) do return true
	naive_join(&child, scan.position + 1)
	return true
}

// naive_materialize is intentionally test-only: it scans the full fact set for
// every body atom, providing a small-graph correctness baseline for semi-naive.
@(private) naive_materialize :: proc(target: ^store.Store, rules: []Rule) {
	changed := true
	for changed {
		changed = false
		for rule_index in 0..<len(rules) {
			state := Naive_State{target = target, rule = &rules[rule_index], changed = &changed}
			naive_join(&state, 0)
		}
	}
}

@(private) stores_equal :: proc(left, right: ^store.Store) -> bool {
	if store.fact_count(left) != store.fact_count(right) do return false
	for index in 0..<store.fact_count(left) {
		id, _, _, found := store.fact_at(left, index)
		if !found do return false
		triple, valid := store.triple_for(left, id)
		if !valid || !contains_triple(right, triple) do return false
	}
	return true
}

@(test)
test_semi_naive_matches_naive_baseline_on_small_graph :: proc(t: ^testing.T) {
	semi_naive: store.Store
	naive: store.Store
	seed_chain(t, &semi_naive)
	seed_chain(t, &naive)
	defer store.destroy(&semi_naive)
	defer store.destroy(&naive)
	semi_ids := ids_for(&semi_naive)
	naive_ids := ids_for(&naive)
	semi_definition: Transitive_Rule
	naive_definition: Transitive_Rule
	init_transitive_rule(&semi_definition, semi_ids[4])
	init_transitive_rule(&naive_definition, naive_ids[4])
	semi_rule := transitive_rule(&semi_definition)
	naive_rule := transitive_rule(&naive_definition)
	materializer: Materializer
	init(&materializer)
	defer destroy(&materializer)
	result := materialize(&materializer, &semi_naive, []Rule{semi_rule})
	testing.expect_value(t, result.error, Error_Code.None)
	naive_materialize(&naive, []Rule{naive_rule})
	testing.expect(t, stores_equal(&semi_naive, &naive))
}

@(test)
test_round_and_derivation_limits_do_not_commit_partial_closure :: proc(t: ^testing.T) {
	for limit_kind in 0..<2 {
		target: store.Store
		seed_chain(t, &target)
		ids := ids_for(&target)
		definition: Transitive_Rule
		init_transitive_rule(&definition, ids[4])
		rule := transitive_rule(&definition)
		materializer: Materializer
		init(&materializer)
		options := limit_kind == 0 ? Options{max_rounds = 1} : Options{max_derivations = 1}
		result := materialize(&materializer, &target, []Rule{rule}, options)
		if limit_kind == 0 {
			testing.expect_value(t, result.error, Error_Code.Max_Rounds)
		} else {
			testing.expect_value(t, result.error, Error_Code.Max_Derivations)
		}
		testing.expect_value(t, result.inferred_facts, 0)
		testing.expect_value(t, store.fact_count(&target), 3)
		testing.expect_value(t, derivation_count(&materializer), 0)
		destroy(&materializer)
		store.destroy(&target)
	}
}
