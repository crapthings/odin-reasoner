package importer

import "core:testing"
import rdf "odin-rdf:rdf"
import store "../store"
import turtle "odin-rdf:rdf/turtle"

@(test)
test_turtle_sink_immediately_owns_terms_and_preserves_blank_scopes :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	state: Sink_State
	init(&state, &target)

	first := turtle.parse("_:same <urn:p> \"first\" .", triple_sink, {}, &state)
	second := turtle.parse("_:same <urn:p> \"second\" .", triple_sink, {}, &state)
	testing.expect_value(t, first.code, turtle.Error_Code.None)
	testing.expect_value(t, second.code, turtle.Error_Code.None)
	testing.expect_value(t, state.last_error, store.Error_Code.None)
	testing.expect_value(t, state.inserted, 2)
	testing.expect_value(t, store.fact_count(&target), 2)
	testing.expect_value(t, store.term_count(&target), 5)

	triple, found := store.triple_for(&target, store.Fact_ID(1))
	second_triple, second_found := store.triple_for(&target, store.Fact_ID(2))
	testing.expect(t, found)
	testing.expect(t, second_found)
	testing.expect_value(t, triple.subject.kind, rdf.Term_Kind.Blank_Node)
	testing.expect_value(t, triple.subject.value, "same")
	testing.expect_value(t, triple.object.value, "first")
	testing.expect(t, triple.subject.scope != second_triple.subject.scope)
}

@(test)
test_sink_exposes_limit_error_to_parser :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target, {max_facts = 1}), store.Error_Code.None)
	defer store.destroy(&target)
	state: Sink_State
	init(&state, &target)
	result := turtle.parse("<urn:s1> <urn:p> <urn:o> . <urn:s2> <urn:p> <urn:o> .", triple_sink, {}, &state)
	testing.expect_value(t, result.code, turtle.Error_Code.Stopped)
	testing.expect_value(t, state.last_error, store.Error_Code.Fact_Limit)
	testing.expect_value(t, store.fact_count(&target), 1)
}
