package owlrl

import "core:os"
import "core:testing"
import rdf "odin-rdf:rdf"
import ntriples "odin-rdf:rdf/ntriples"
import importer "../import"
import store "../store"
import term "../term"

@(private) Corpus_Case :: struct {
	input_path:    string,
	expected_path: string,
}

@(private) Failure_Case :: struct {
	input_path:          string,
	options:             Materialize_All_Options,
	expected_error:      Materialize_All_Error_Code,
	expected_list_error: List_Error_Code,
	checks_list_error:   bool,
}

@(private) load_ntriples_fixture :: proc(t: ^testing.T, path: string, target: ^store.Store) -> bool {
	data, read_error := os.read_entire_file(path, context.allocator)
	if read_error != nil {
		testing.expect(t, false)
		return false
	}
	defer delete(data)

	state: importer.Sink_State
	importer.init(&state, target)
	parsed := ntriples.parse(string(data), importer.triple_sink, &state)
	testing.expect_value(t, parsed.code, ntriples.Error_Code.None)
	testing.expect_value(t, state.last_error, store.Error_Code.None)
	return parsed.code == .None && state.last_error == .None
}

// Fixture_Binding records one existential blank-node assignment while checking
// an expected RDF graph against the materialized target graph. Expected blank
// nodes are existential variables: they may match any target RDF term, and
// multiple expected blank nodes need not map injectively.
@(private) Fixture_Binding :: struct {
	expected: term.Term_ID,
	target:   term.Term_ID,
}

@(private) bound_fixture_term :: proc(bindings: []Fixture_Binding, expected: term.Term_ID) -> (term.Term_ID, bool) {
	for binding in bindings {
		if binding.expected == expected do return binding.target, true
	}
	return term.INVALID_TERM_ID, false
}

// fixture_term_matches binds expected blank nodes as needed. Constants use the
// target dictionary's RDF-term equality, so parsed fixture scopes never leak
// into IRI or literal comparisons.
@(private) fixture_term_matches :: proc(target, expected: ^store.Store, expected_id, candidate_id: term.Term_ID, bindings: ^[dynamic]Fixture_Binding) -> bool {
	expected_term, expected_found := store.get_term(expected, expected_id)
	if !expected_found do return false
	if expected_term.kind != .Blank_Node do return store.id_for_term(target, expected_term) == candidate_id
	if bound, found := bound_fixture_term(bindings^[:], expected_id); found do return bound == candidate_id
	_, append_error := append(bindings, Fixture_Binding{expected = expected_id, target = candidate_id})
	return append_error == nil
}

@(private) fixture_fact_matches :: proc(target, expected: ^store.Store, expected_fact, candidate: store.Fact, bindings: ^[dynamic]Fixture_Binding) -> bool {
	start := len(bindings^)
	if !fixture_term_matches(target, expected, expected_fact.subject, candidate.subject, bindings) {
		resize(bindings, start)
		return false
	}
	if !fixture_term_matches(target, expected, expected_fact.predicate, candidate.predicate, bindings) {
		resize(bindings, start)
		return false
	}
	if !fixture_term_matches(target, expected, expected_fact.object, candidate.object, bindings) {
		resize(bindings, start)
		return false
	}
	return true
}

// fixture_graph_entails recognizes RDF simple entailment for the expected
// fixture graph: IRIs and literals are fixed, while blank nodes are
// existentially mapped into the materialized graph. It deliberately does not
// require a graph isomorphism or an injective blank-node mapping.
@(private) fixture_graph_entails :: proc(target, expected: ^store.Store, expected_index: int = 0, bindings: ^[dynamic]Fixture_Binding = nil) -> bool {
	if expected_index == store.fact_count(expected) do return true
	_, expected_fact, _, expected_found := store.fact_at(expected, expected_index)
	if !expected_found do return false
	for candidate_index in 0..<store.fact_count(target) {
		_, candidate, _, candidate_found := store.fact_at(target, candidate_index)
		if !candidate_found do return false
		start := len(bindings^)
		if !fixture_fact_matches(target, expected, expected_fact, candidate, bindings) do continue
		if fixture_graph_entails(target, expected, expected_index + 1, bindings) do return true
		resize(bindings, start)
	}
	return false
}

@(private) expect_fixture_conclusions :: proc(t: ^testing.T, target, expected: ^store.Store) {
	testing.expect(t, store.fact_count(expected) > 0)
	bindings := make([dynamic]Fixture_Binding)
	defer delete(bindings)
	testing.expect(t, fixture_graph_entails(target, expected, 0, &bindings))
}

@(private) add_fixture_test_triple :: proc(t: ^testing.T, target: ^store.Store, triple: rdf.Triple) {
	added, error := store.insert_triple(target, triple)
	testing.expect(t, added)
	testing.expect_value(t, error, store.Error_Code.None)
}

@(test)
test_fixture_graph_entailment_maps_expected_blank_nodes_consistently :: proc(t: ^testing.T) {
	type := rdf.iri("http://www.w3.org/1999/02/22-rdf-syntax-ns#type")
	complement_of := rdf.iri("http://www.w3.org/2002/07/owl#complementOf")
	alice, woman := rdf.iri("urn:alice"), rdf.iri("urn:woman")

	expected: store.Store
	testing.expect_value(t, store.init(&expected), store.Error_Code.None)
	defer store.destroy(&expected)
	expected_class := rdf.blank_node("expected-class", rdf.new_blank_node_scope())
	add_fixture_test_triple(t, &expected, {alice, type, expected_class})
	add_fixture_test_triple(t, &expected, {expected_class, complement_of, woman})

	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	generated_class := rdf.blank_node("generated-class", rdf.new_blank_node_scope())
	add_fixture_test_triple(t, &target, {alice, type, generated_class})
	add_fixture_test_triple(t, &target, {generated_class, complement_of, woman})
	bindings := make([dynamic]Fixture_Binding)
	defer delete(bindings)
	testing.expect(t, fixture_graph_entails(&target, &expected, 0, &bindings))

	unlinked: store.Store
	testing.expect_value(t, store.init(&unlinked), store.Error_Code.None)
	defer store.destroy(&unlinked)
	first := rdf.blank_node("first", rdf.new_blank_node_scope())
	second := rdf.blank_node("second", rdf.new_blank_node_scope())
	add_fixture_test_triple(t, &unlinked, {alice, type, first})
	add_fixture_test_triple(t, &unlinked, {second, complement_of, woman})
	clear(&bindings)
	testing.expect(t, !fixture_graph_entails(&unlinked, &expected, 0, &bindings))
}

@(private) run_closure_fixture :: proc(t: ^testing.T, fixture: Corpus_Case) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	if !load_ntriples_fixture(t, fixture.input_path, &target) do return

	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)

	// Corpus fixtures are intentionally tiny. Keep a finite closure budget here
	// so a regression in rule interaction fails deterministically instead of
	// leaving an unbounded test executable consuming the developer's machine.
	result := materialize_all(&profile, &target, {
		max_rounds = 64,
		max_derivations = 10_000,
		max_list_items = 8,
		max_path_states = 8,
	})
	testing.expect_value(t, result.error, Materialize_All_Error_Code.None)
	if result.error != .None do return
	testing.expect_value(t, closure_derivation_count(&profile), result.inferred_facts)

	expected: store.Store
	testing.expect_value(t, store.init(&expected), store.Error_Code.None)
	defer store.destroy(&expected)
	if len(fixture.expected_path) > 0 {
		if !load_ntriples_fixture(t, fixture.expected_path, &expected) do return
		expect_fixture_conclusions(t, &target, &expected)
	}
}

@(private) run_checked_fixture :: proc(t: ^testing.T, fixture: Corpus_Case, expected_violation: Violation_Kind) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	if !load_ntriples_fixture(t, fixture.input_path, &target) do return

	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)
	report: Report
	init_report(&report)
	defer destroy_report(&report)

	result := materialize_all_checked(&profile, &target, &report, {max_list_items = 8, max_path_states = 8})
	testing.expect_value(t, result.materialization.error, Materialize_All_Error_Code.None)
	testing.expect_value(t, result.consistency, Consistency_Error_Code.None)
	testing.expect(t, !result.consistent)
	testing.expect(t, has_kind(&report, expected_violation))

	expected: store.Store
	testing.expect_value(t, store.init(&expected), store.Error_Code.None)
	defer store.destroy(&expected)
	if len(fixture.expected_path) > 0 {
		if !load_ntriples_fixture(t, fixture.expected_path, &expected) do return
		expect_fixture_conclusions(t, &target, &expected)
	}
}

@(private) run_generalized_datatype_checked_fixture :: proc(t: ^testing.T, input_path: string, expected_violation: Violation_Kind) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	if !load_ntriples_fixture(t, input_path, &target) do return

	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)
	report: Report
	init_report(&report)
	defer destroy_report(&report)

	result := materialize_generalized_datatypes_checked(&profile, &target, &report)
	testing.expect_value(t, result.materialization.error, Generalized_Datatype_Error_Code.None)
	testing.expect_value(t, result.consistency, Consistency_Error_Code.None)
	testing.expect(t, !result.consistent)
	testing.expect(t, has_kind(&report, expected_violation))
}

@(private) run_failure_fixture :: proc(t: ^testing.T, fixture: Failure_Case) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	if !load_ntriples_fixture(t, fixture.input_path, &target) do return

	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)
	before := store.fact_count(&target)

	result := materialize_all(&profile, &target, fixture.options)
	testing.expect_value(t, result.error, fixture.expected_error)
	if fixture.checks_list_error do testing.expect_value(t, result.list_error, fixture.expected_list_error)
	testing.expect_value(t, store.fact_count(&target), before)
	testing.expect_value(t, closure_derivation_count(&profile), 0)
}

@(test)
test_fixture_corpus_materializes_supported_rule_clusters :: proc(t: ^testing.T) {
	fixtures := [30]Corpus_Case{
		{input_path = "reasoner/owlrl/testdata/01-schema-identity.input.nt", expected_path = "reasoner/owlrl/testdata/01-schema-identity.expected.nt"},
		{input_path = "reasoner/owlrl/testdata/02-property-relations.input.nt", expected_path = "reasoner/owlrl/testdata/02-property-relations.expected.nt"},
		{input_path = "reasoner/owlrl/testdata/03-restrictions-self.input.nt", expected_path = "reasoner/owlrl/testdata/03-restrictions-self.expected.nt"},
		{input_path = "reasoner/owlrl/testdata/04-lists-chain.input.nt", expected_path = "reasoner/owlrl/testdata/04-lists-chain.expected.nt"},
		{input_path = "reasoner/owlrl/testdata/05-declarations.input.nt", expected_path = "reasoner/owlrl/testdata/05-declarations.expected.nt"},
		{input_path = "reasoner/owlrl/testdata/w3c-object-property-chain-001.input.nt", expected_path = "reasoner/owlrl/testdata/w3c-object-property-chain-001.expected.nt"},
		{input_path = "reasoner/owlrl/testdata/w3c-object-property-chain-bjp-003.input.nt", expected_path = "reasoner/owlrl/testdata/w3c-object-property-chain-bjp-003.expected.nt"},
		{input_path = "reasoner/owlrl/testdata/w3c-chain2trans1.input.nt", expected_path = "reasoner/owlrl/testdata/w3c-chain2trans1.expected.nt"},
		{input_path = "reasoner/owlrl/testdata/w3c-keys-003.input.nt", expected_path = "reasoner/owlrl/testdata/w3c-keys-003.expected.nt"},
		{input_path = "reasoner/owlrl/testdata/w3c-equivalent-property-002.input.nt", expected_path = "reasoner/owlrl/testdata/w3c-equivalent-property-002.expected.nt"},
		{input_path = "reasoner/owlrl/testdata/w3c-equivalent-property-003.input.nt", expected_path = "reasoner/owlrl/testdata/w3c-equivalent-property-003.expected.nt"},
		{input_path = "reasoner/owlrl/testdata/w3c-equivalent-class-002.input.nt", expected_path = "reasoner/owlrl/testdata/w3c-equivalent-class-002.expected.nt"},
		{input_path = "reasoner/owlrl/testdata/w3c-equivalent-class-003.input.nt", expected_path = "reasoner/owlrl/testdata/w3c-equivalent-class-003.expected.nt"},
		{input_path = "reasoner/owlrl/testdata/w3c-same-as-001.input.nt", expected_path = "reasoner/owlrl/testdata/w3c-same-as-001.expected.nt"},
		{input_path = "reasoner/owlrl/testdata/w3c-different-from-001.input.nt", expected_path = "reasoner/owlrl/testdata/w3c-different-from-001.expected.nt"},
		{input_path = "reasoner/owlrl/testdata/w3c-i5-8-011.input.nt", expected_path = "reasoner/owlrl/testdata/w3c-i5-8-011.expected.nt"},
		{input_path = "reasoner/owlrl/testdata/w3c-i5-8-006.input.nt", expected_path = "reasoner/owlrl/testdata/w3c-i5-8-006.expected.nt"},
		{input_path = "reasoner/owlrl/testdata/w3c-i5-8-008.input.nt", expected_path = "reasoner/owlrl/testdata/w3c-i5-8-008.expected.nt"},
		{input_path = "reasoner/owlrl/testdata/w3c-i5-8-009.input.nt", expected_path = "reasoner/owlrl/testdata/w3c-i5-8-009.expected.nt"},
		{input_path = "reasoner/owlrl/testdata/w3c-reflexive-property-001.input.nt", expected_path = "reasoner/owlrl/testdata/w3c-reflexive-property-001.expected.nt"},
		{input_path = "reasoner/owlrl/testdata/w3c-disjoint-data-properties-002.input.nt", expected_path = "reasoner/owlrl/testdata/w3c-disjoint-data-properties-002.expected.nt"},
		{input_path = "reasoner/owlrl/testdata/w3c-disjoint-object-properties-001.input.nt", expected_path = "reasoner/owlrl/testdata/w3c-disjoint-object-properties-001.expected.nt"},
		{input_path = "reasoner/owlrl/testdata/w3c-disjoint-object-properties-002.input.nt", expected_path = "reasoner/owlrl/testdata/w3c-disjoint-object-properties-002.expected.nt"},
		{input_path = "reasoner/owlrl/testdata/w3c-functional-property-different-from.input.nt", expected_path = "reasoner/owlrl/testdata/w3c-functional-property-different-from.expected.nt"},
		{input_path = "reasoner/owlrl/testdata/w3c-inverse-functional-property-different-from.input.nt", expected_path = "reasoner/owlrl/testdata/w3c-inverse-functional-property-different-from.expected.nt"},
		{input_path = "reasoner/owlrl/testdata/w3c-disjoint-classes-001.input.nt", expected_path = "reasoner/owlrl/testdata/w3c-disjoint-classes-001.expected.nt"},
		{input_path = "reasoner/owlrl/testdata/w3c-disjoint-classes-003.input.nt", expected_path = "reasoner/owlrl/testdata/w3c-disjoint-classes-003.expected.nt"},
		{input_path = "reasoner/owlrl/testdata/w3c-object-qcr-002.input.nt", expected_path = "reasoner/owlrl/testdata/w3c-object-qcr-002.expected.nt"},
		{input_path = "reasoner/owlrl/testdata/w3c-i5-26-010.input.nt", expected_path = "reasoner/owlrl/testdata/w3c-i5-26-010.expected.nt"},
		{input_path = "reasoner/owlrl/testdata/w3c-i5-5-005.input.nt", expected_path = "reasoner/owlrl/testdata/w3c-i5-5-005.expected.nt"},
	}
	for fixture in fixtures do run_closure_fixture(t, fixture)
}

@(test)
test_fixture_corpus_reports_list_derived_conflicts_after_closure :: proc(t: ^testing.T) {
	run_checked_fixture(t, {
		input_path = "reasoner/owlrl/testdata/06-list-conflict.input.nt",
		expected_path = "reasoner/owlrl/testdata/06-list-conflict.expected.nt",
	}, .Disjoint_Classes)
}

@(test)
test_fixture_corpus_reports_pinned_w3c_rl_rdf_conflicts :: proc(t: ^testing.T) {
	fixtures := [7]Failure_Case{
		{input_path = "reasoner/owlrl/testdata/w3c-disjoint-data-properties-001.input.nt"},
		{input_path = "reasoner/owlrl/testdata/w3c-asymmetric-property-001.input.nt"},
		{input_path = "reasoner/owlrl/testdata/w3c-negative-object-property-assertion-001.input.nt"},
		{input_path = "reasoner/owlrl/testdata/w3c-negative-data-property-assertion-001.input.nt"},
		{input_path = "reasoner/owlrl/testdata/w3c-disjoint-classes-002.input.nt"},
		{input_path = "reasoner/owlrl/testdata/w3c-irreflexive-property-001.input.nt"},
		{input_path = "reasoner/owlrl/testdata/w3c-nothing-001.input.nt"},
	}
	violations := [7]Violation_Kind{
		.Disjoint_Properties,
		.Asymmetric_Property,
		.Negative_Property_Assertion,
		.Negative_Property_Assertion,
		.Disjoint_Classes,
		.Irreflexive_Property,
		.Nothing_Instance,
	}
	for index in 0..<len(fixtures) {
		run_checked_fixture(t, {input_path = fixtures[index].input_path}, violations[index])
	}
}

@(test)
test_fixture_corpus_reports_pinned_w3c_rl_rdf_signed_zero_datatype_conflict :: proc(t: ^testing.T) {
	// The source test is expressed only in Functional Syntax. This normalized
	// RDF projection isolates its W3C RL/RDF rule interaction: dt-diff for the
	// two distinct float values, prp-fp, and eq-diff1.
	run_generalized_datatype_checked_fixture(t, "reasoner/owlrl/testdata/w3c-plus-minus-zero.input.nt", .Same_As_Different_From)
}

@(test)
test_fixture_corpus_reports_pinned_w3c_rl_rdf_functionality_datatype_conflict :: proc(t: ^testing.T) {
	// The archive cases exercise functional data-property collision over distinct
	// integer and string values. They require generalized literal-subject heads.
	run_generalized_datatype_checked_fixture(t, "reasoner/owlrl/testdata/w3c-functionality-clash.input.nt", .Same_As_Different_From)
	run_generalized_datatype_checked_fixture(t, "reasoner/owlrl/testdata/w3c-keys-006.input.nt", .Same_As_Different_From)
}

@(test)
test_fixture_corpus_reports_pinned_w3c_rl_rdf_datatype_range_conflict :: proc(t: ^testing.T) {
	// This source case requires an invalid value inferred into an xsd:integer
	// range, so its dt-not-type conclusion needs generalized literal-subject heads.
	run_generalized_datatype_checked_fixture(t, "reasoner/owlrl/testdata/w3c-string-integer-clash.input.nt", .Datatype_Not_Type)
}

@(test)
test_fixture_corpus_keeps_materialization_failures_atomic :: proc(t: ^testing.T) {
	fixtures := [2]Failure_Case{
		{
			input_path = "reasoner/owlrl/testdata/07-malformed-list.input.nt",
			expected_error = .List_Error,
			expected_list_error = .Missing_Rest,
			checks_list_error = true,
		},
		{
			input_path = "reasoner/owlrl/testdata/08-path-limit.input.nt",
			options = {max_path_states = 1},
			expected_error = .Path_State_Limit,
		},
	}
	for fixture in fixtures do run_failure_fixture(t, fixture)
}
