package owlrl

import "core:os"
import "core:testing"
import ntriples "odin-rdf:rdf/ntriples"
import importer "../import"
import store "../store"

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

@(private) expect_fixture_conclusions :: proc(t: ^testing.T, target, expected: ^store.Store) {
	testing.expect(t, store.fact_count(expected) > 0)
	for index in 0..<store.fact_count(expected) {
		id, _, _, found := store.fact_at(expected, index)
		testing.expect(t, found)
		if !found do continue
		triple, triple_found := store.triple_for(expected, id)
		testing.expect(t, triple_found)
		if triple_found do testing.expect(t, has(target, triple))
	}
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

	result := materialize_all(&profile, &target, {max_list_items = 8, max_path_states = 8})
	testing.expect_value(t, result.error, Materialize_All_Error_Code.None)
	if result.error != .None do return
	testing.expect_value(t, closure_derivation_count(&profile), result.inferred_facts)

	expected: store.Store
	testing.expect_value(t, store.init(&expected), store.Error_Code.None)
	defer store.destroy(&expected)
	if !load_ntriples_fixture(t, fixture.expected_path, &expected) do return
	expect_fixture_conclusions(t, &target, &expected)
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
	if !load_ntriples_fixture(t, fixture.expected_path, &expected) do return
	expect_fixture_conclusions(t, &target, &expected)
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
	fixtures := [5]Corpus_Case{
		{input_path = "reasoner/owlrl/testdata/01-schema-identity.input.nt", expected_path = "reasoner/owlrl/testdata/01-schema-identity.expected.nt"},
		{input_path = "reasoner/owlrl/testdata/02-property-relations.input.nt", expected_path = "reasoner/owlrl/testdata/02-property-relations.expected.nt"},
		{input_path = "reasoner/owlrl/testdata/03-restrictions-self.input.nt", expected_path = "reasoner/owlrl/testdata/03-restrictions-self.expected.nt"},
		{input_path = "reasoner/owlrl/testdata/04-lists-chain.input.nt", expected_path = "reasoner/owlrl/testdata/04-lists-chain.expected.nt"},
		{input_path = "reasoner/owlrl/testdata/05-declarations.input.nt", expected_path = "reasoner/owlrl/testdata/05-declarations.expected.nt"},
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
