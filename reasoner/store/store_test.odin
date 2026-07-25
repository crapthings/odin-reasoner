package store

import "core:testing"
import rdf "odin-rdf:rdf"
import term "../term"

@(private) Count_State :: struct { count: int, ids: [dynamic]Fact_ID }

@(private) count_sink :: proc(id: Fact_ID, _: Fact, _: Origin, user_data: rawptr) -> bool {
	state := cast(^Count_State)user_data
	state.count += 1
	append(&state.ids, id)
	return true
}

@(private) count_pattern :: proc(t: ^testing.T, store: ^Store, pattern: Pattern, expected: int) {
	state := Count_State{ids = make([dynamic]Fact_ID)}
	defer delete(state.ids)
	result := match(store, pattern, count_sink, &state)
	testing.expect_value(t, result.error, Error_Code.None)
	testing.expect(t, !result.stopped)
	testing.expect_value(t, result.matched, expected)
	testing.expect_value(t, state.count, expected)
}

@(private) setup_four_facts :: proc(t: ^testing.T, target: ^Store) -> [5]term.Term_ID {
	testing.expect_value(t, init(target), Error_Code.None)
	triples := [4]rdf.Triple{
		{rdf.iri("urn:s1"), rdf.iri("urn:p1"), rdf.iri("urn:o1")},
		{rdf.iri("urn:s1"), rdf.iri("urn:p1"), rdf.iri("urn:o2")},
		{rdf.iri("urn:s1"), rdf.iri("urn:p2"), rdf.iri("urn:o1")},
		{rdf.iri("urn:s2"), rdf.iri("urn:p1"), rdf.iri("urn:o1")},
	}
	for triple in triples {
		added, error := insert_triple(target, triple)
		testing.expect(t, added)
		testing.expect_value(t, error, Error_Code.None)
	}
	return [5]term.Term_ID{
		term.id_for(&target.dictionary, rdf.iri("urn:s1")),
		term.id_for(&target.dictionary, rdf.iri("urn:s2")),
		term.id_for(&target.dictionary, rdf.iri("urn:p1")),
		term.id_for(&target.dictionary, rdf.iri("urn:p2")),
		term.id_for(&target.dictionary, rdf.iri("urn:o1")),
	}
}

@(test)
test_set_semantics_and_first_origin :: proc(t: ^testing.T) {
	target: Store
	testing.expect_value(t, init(&target), Error_Code.None)
	defer destroy(&target)
	triple := rdf.Triple{rdf.iri("urn:s"), rdf.iri("urn:p"), rdf.iri("urn:o")}
	added, first_error := insert_triple(&target, triple, .Asserted)
	again, duplicate_error := insert_triple(&target, triple, .Inferred)
	testing.expect(t, added)
	testing.expect(t, !again)
	testing.expect_value(t, first_error, Error_Code.None)
	testing.expect_value(t, duplicate_error, Error_Code.None)
	testing.expect_value(t, fact_count(&target), 1)
	origin, found := origin_for(&target, Fact_ID(1))
	testing.expect(t, found)
	testing.expect_value(t, origin, Origin.Asserted)
}

@(test)
test_match_every_constant_wildcard_combination :: proc(t: ^testing.T) {
	target: Store
	ids := setup_four_facts(t, &target)
	defer destroy(&target)
	s1, p1, o1 := ids[0], ids[2], ids[4]

	count_pattern(t, &target, {}, 4)
	count_pattern(t, &target, {subject = s1}, 3)
	count_pattern(t, &target, {predicate = p1}, 3)
	count_pattern(t, &target, {object = o1}, 3)
	count_pattern(t, &target, {subject = s1, predicate = p1}, 2)
	count_pattern(t, &target, {subject = s1, object = o1}, 2)
	count_pattern(t, &target, {predicate = p1, object = o1}, 2)
	count_pattern(t, &target, {subject = s1, predicate = p1, object = o1}, 1)
}

@(test)
test_fact_and_lexical_limits_leave_state_unchanged :: proc(t: ^testing.T) {
	fact_limited: Store
	testing.expect_value(t, init(&fact_limited, {max_facts = 1}), Error_Code.None)
	defer destroy(&fact_limited)
	_, first_error := insert_triple(&fact_limited, {rdf.iri("urn:s"), rdf.iri("urn:p"), rdf.iri("urn:o")})
	testing.expect_value(t, first_error, Error_Code.None)
	before_terms := term_count(&fact_limited)
	_, fact_error := insert_triple(&fact_limited, {rdf.iri("urn:new-s"), rdf.iri("urn:new-p"), rdf.iri("urn:new-o")})
	testing.expect_value(t, fact_error, Error_Code.Fact_Limit)
	testing.expect_value(t, fact_count(&fact_limited), 1)
	testing.expect_value(t, term_count(&fact_limited), before_terms)

	lexical_limited: Store
	testing.expect_value(t, init(&lexical_limited, {max_lexical_bytes = 14}), Error_Code.None)
	defer destroy(&lexical_limited)
	_, lexical_error := insert_triple(&lexical_limited, {rdf.iri("urn:s"), rdf.iri("urn:p"), rdf.iri("urn:o")})
	testing.expect_value(t, lexical_error, Error_Code.Lexical_Bytes_Limit)
	testing.expect_value(t, fact_count(&lexical_limited), 0)
	testing.expect_value(t, term_count(&lexical_limited), 0)
}

@(test)
test_clone_and_commit_inferred_preserve_ids_and_origins :: proc(t: ^testing.T) {
	target: Store
	testing.expect_value(t, init(&target), Error_Code.None)
	defer destroy(&target)
	asserted := rdf.Triple{rdf.iri("urn:a"), rdf.iri("urn:p"), rdf.iri("urn:o")}
	added, insert_error := insert_triple(&target, asserted)
	testing.expect(t, added)
	testing.expect_value(t, insert_error, Error_Code.None)
	work: Store
	testing.expect_value(t, clone(&target, &work), Error_Code.None)
	defer destroy(&work)
	testing.expect_value(t, term_count(&work), term_count(&target))
	testing.expect_value(t, fact_count(&work), fact_count(&target))
	inferred := rdf.Triple{rdf.iri("urn:a"), rdf.iri("urn:p"), rdf.iri("urn:a")}
	_, inferred_error := insert_triple(&work, inferred, .Inferred)
	testing.expect_value(t, inferred_error, Error_Code.None)
	committed, commit_error := commit_inferred(&work, &target)
	testing.expect_value(t, commit_error, Error_Code.None)
	testing.expect_value(t, committed, 1)
	testing.expect_value(t, fact_count(&target), 2)
	inferred_fact := Fact{
		subject = term.id_for(&target.dictionary, inferred.subject),
		predicate = term.id_for(&target.dictionary, inferred.predicate),
		object = term.id_for(&target.dictionary, inferred.object),
	}
	inferred_id := id_for_fact(&target, inferred_fact)
	origin, found := origin_for(&target, inferred_id)
	testing.expect(t, found)
	testing.expect_value(t, origin, Origin.Inferred)
}

@(test)
test_commit_inferred_admits_fresh_terms_without_changing_existing_ids :: proc(t: ^testing.T) {
	target: Store
	testing.expect_value(t, init(&target), Error_Code.None)
	defer destroy(&target)
	asserted := rdf.Triple{rdf.iri("urn:a"), rdf.iri("urn:p"), rdf.iri("urn:o")}
	_, asserted_error := insert_triple(&target, asserted)
	testing.expect_value(t, asserted_error, Error_Code.None)
	asserted_subject := term.id_for(&target.dictionary, asserted.subject)

	work: Store
	testing.expect_value(t, clone(&target, &work), Error_Code.None)
	defer destroy(&work)
	fresh := rdf.blank_node("generated", rdf.new_blank_node_scope())
	inferred := rdf.Triple{rdf.iri("urn:a"), rdf.iri("urn:derived"), fresh}
	added, inferred_error := insert_triple(&work, inferred, .Inferred)
	testing.expect(t, added)
	testing.expect_value(t, inferred_error, Error_Code.None)

	committed, commit_error := commit_inferred(&work, &target)
	testing.expect_value(t, commit_error, Error_Code.None)
	testing.expect_value(t, committed, 1)
	testing.expect_value(t, term.id_for(&target.dictionary, asserted.subject), asserted_subject)
	testing.expect(t, term.id_for(&target.dictionary, fresh) != term.INVALID_TERM_ID)
	inferred_fact := Fact{
		subject = term.id_for(&target.dictionary, inferred.subject),
		predicate = term.id_for(&target.dictionary, inferred.predicate),
		object = term.id_for(&target.dictionary, inferred.object),
	}
	testing.expect(t, contains(&target, inferred_fact))
}
