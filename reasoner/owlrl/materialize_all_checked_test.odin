package owlrl

import "core:testing"
import rdf "odin-rdf:rdf"
import rdfs "../rdfs"
import store "../store"
import term "../term"

@(private) add_all_checked_fact :: proc(t: ^testing.T, target: ^store.Store, triple: rdf.Triple) {
	added, error := store.insert_triple(target, triple)
	testing.expect(t, added)
	testing.expect_value(t, error, store.Error_Code.None)
}

@(private) has_all_checked_fact :: proc(target: ^store.Store, triple: rdf.Triple) -> bool {
	fact := store.Fact{
		subject = term.id_for(&target.dictionary, triple.subject),
		predicate = term.id_for(&target.dictionary, triple.predicate),
		object = term.id_for(&target.dictionary, triple.object),
	}
	return fact.subject != term.INVALID_TERM_ID && fact.predicate != term.INVALID_TERM_ID && fact.object != term.INVALID_TERM_ID && store.contains(target, fact)
}

@(private) all_checked_has_kind :: proc(report: ^Report, wanted: Violation_Kind) -> bool {
	for index in 0..<violation_count(report) {
		violation, found := violation_at(report, index)
		if found && violation.kind == wanted do return true
	}
	return false
}

@(test)
test_materialize_all_checked_reports_dynamic_list_contradictions_after_commit :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)
	report: Report
	init_report(&report)
	defer destroy_report(&report)

	choice, incompatible, x := rdf.iri("urn:Choice"), rdf.iri("urn:Incompatible"), rdf.iri("urn:x")
	head := rdf.blank_node("one", rdf.Blank_Node_Scope(41))
	add_all_checked_fact(t, &target, {choice, rdf.iri(OWL_ONE_OF), head})
	add_all_checked_fact(t, &target, {head, rdf.iri(RDF_FIRST), x})
	add_all_checked_fact(t, &target, {head, rdf.iri(RDF_REST), rdf.iri(RDF_NIL)})
	add_all_checked_fact(t, &target, {choice, rdf.iri(OWL_DISJOINT_WITH), incompatible})
	add_all_checked_fact(t, &target, {x, rdf.iri(rdfs.RDF_TYPE), incompatible})

	result := materialize_all_checked(&profile, &target, &report)
	testing.expect_value(t, result.materialization.error, Materialize_All_Error_Code.None)
	testing.expect_value(t, result.consistency, Consistency_Error_Code.None)
	testing.expect(t, !result.consistent)
	testing.expect(t, has_all_checked_fact(&target, {x, rdf.iri(rdfs.RDF_TYPE), choice}))
	testing.expect(t, all_checked_has_kind(&report, .Disjoint_Classes))
	testing.expect(t, closure_derivation_count(&profile) > 0)
}

@(test)
test_materialize_all_checked_keeps_dynamic_failure_transactional_and_clears_report :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)
	report: Report
	init_report(&report)
	defer destroy_report(&report)

	choice, good_head, broken_head := rdf.iri("urn:Choice"), rdf.blank_node("good", rdf.Blank_Node_Scope(42)), rdf.blank_node("broken", rdf.Blank_Node_Scope(42))
	add_all_checked_fact(t, &target, {choice, rdf.iri(OWL_ONE_OF), good_head})
	add_all_checked_fact(t, &target, {good_head, rdf.iri(RDF_FIRST), rdf.iri("urn:x")})
	add_all_checked_fact(t, &target, {good_head, rdf.iri(RDF_REST), rdf.iri(RDF_NIL)})
	add_all_checked_fact(t, &target, {rdf.iri("urn:Broken"), rdf.iri(OWL_UNION_OF), broken_head})
	add_all_checked_fact(t, &target, {broken_head, rdf.iri(RDF_FIRST), rdf.iri("urn:C")})
	before := store.fact_count(&target)

	result := materialize_all_checked(&profile, &target, &report)
	testing.expect_value(t, result.materialization.error, Materialize_All_Error_Code.List_Error)
	testing.expect_value(t, violation_count(&report), 0)
	testing.expect_value(t, store.fact_count(&target), before)
	testing.expect(t, !has_all_checked_fact(&target, {rdf.iri("urn:x"), rdf.iri(rdfs.RDF_TYPE), choice}))
}

@(test)
test_materialize_all_checked_keeps_successful_closure_on_report_limit :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)
	report: Report
	init_report(&report)
	defer destroy_report(&report)

	type := rdf.iri(rdfs.RDF_TYPE)
	add_all_checked_fact(t, &target, {rdf.iri("urn:C1"), rdf.iri(OWL_DISJOINT_WITH), rdf.iri("urn:C2")})
	add_all_checked_fact(t, &target, {rdf.iri("urn:x"), type, rdf.iri("urn:C1")})
	add_all_checked_fact(t, &target, {rdf.iri("urn:x"), type, rdf.iri("urn:C2")})
	add_all_checked_fact(t, &target, {rdf.iri("urn:C3"), rdf.iri(OWL_DISJOINT_WITH), rdf.iri("urn:C4")})
	add_all_checked_fact(t, &target, {rdf.iri("urn:y"), type, rdf.iri("urn:C3")})
	add_all_checked_fact(t, &target, {rdf.iri("urn:y"), type, rdf.iri("urn:C4")})

	result := materialize_all_checked(&profile, &target, &report, {}, {max_violations = 1})
	testing.expect_value(t, result.materialization.error, Materialize_All_Error_Code.None)
	testing.expect_value(t, result.consistency, Consistency_Error_Code.Violation_Limit)
	testing.expect(t, !result.consistent)
	testing.expect_value(t, violation_count(&report), 0)
	testing.expect(t, has_all_checked_fact(&target, {rdf.iri("urn:x"), type, rdf.iri("urn:C1")}))
	testing.expect(t, closure_derivation_count(&profile) > 0)
}
