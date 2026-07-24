package owlrl

import "core:testing"
import rdf "odin-rdf:rdf"
import rdfs "../rdfs"
import rule "../rule"
import store "../store"

@(private) add_consistency_fact :: proc(t: ^testing.T, target: ^store.Store, triple: rdf.Triple) {
	added, error := store.insert_triple(target, triple)
	testing.expect(t, added)
	testing.expect_value(t, error, store.Error_Code.None)
}

@(private) has_kind :: proc(report: ^Report, wanted: Violation_Kind) -> bool {
	for index in 0..<violation_count(report) {
		violation, found := violation_at(report, index)
		if found && violation.kind == wanted do return true
	}
	return false
}

@(private) count_kind :: proc(report: ^Report, wanted: Violation_Kind) -> int {
	count := 0
	for index in 0..<violation_count(report) {
		violation, found := violation_at(report, index)
		if found && violation.kind == wanted do count += 1
	}
	return count
}

@(test)
test_materialize_checked_reports_each_supported_false_rule :: proc(t: ^testing.T) {
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

	type, same_as, different_from := rdf.iri(rdfs.RDF_TYPE), rdf.iri(OWL_SAME_AS), rdf.iri(OWL_DIFFERENT_FROM)
	a, b, u := rdf.iri("urn:a"), rdf.iri("urn:b"), rdf.iri("urn:u")
	c1, c2, c3, c4, c5, c6, x := rdf.iri("urn:C1"), rdf.iri("urn:C2"), rdf.iri("urn:C3"), rdf.iri("urn:C4"), rdf.iri("urn:C5"), rdf.iri("urn:C6"), rdf.iri("urn:x")
	p1, p2, p3, p4, p5, p6, p7, s, o := rdf.iri("urn:p1"), rdf.iri("urn:p2"), rdf.iri("urn:p3"), rdf.iri("urn:p4"), rdf.iri("urn:p5"), rdf.iri("urn:p6"), rdf.iri("urn:p7"), rdf.iri("urn:s"), rdf.iri("urn:o")
	irreflexive, asymmetric := rdf.iri("urn:irreflexive"), rdf.iri("urn:asymmetric")
	m, n := rdf.iri("urn:m"), rdf.iri("urn:n")
	add_consistency_fact(t, &target, {a, same_as, b})
	add_consistency_fact(t, &target, {a, different_from, b})
	add_consistency_fact(t, &target, {c1, rdf.iri(OWL_DISJOINT_WITH), c2})
	add_consistency_fact(t, &target, {x, type, c1})
	add_consistency_fact(t, &target, {x, type, c2})
	add_consistency_fact(t, &target, {c3, rdf.iri(OWL_COMPLEMENT_OF), c4})
	add_consistency_fact(t, &target, {x, type, c3})
	add_consistency_fact(t, &target, {x, type, c4})
	group, n1, n2 := rdf.blank_node("all-disjoint", rdf.Blank_Node_Scope(15)), rdf.blank_node("all-disjoint-1", rdf.Blank_Node_Scope(15)), rdf.blank_node("all-disjoint-2", rdf.Blank_Node_Scope(15))
	add_consistency_fact(t, &target, {group, type, rdf.iri(OWL_ALL_DISJOINT_CLASSES)})
	add_consistency_fact(t, &target, {group, rdf.iri(OWL_MEMBERS), n1})
	add_consistency_fact(t, &target, {n1, rdf.iri(RDF_FIRST), c5})
	add_consistency_fact(t, &target, {n1, rdf.iri(RDF_REST), n2})
	add_consistency_fact(t, &target, {n2, rdf.iri(RDF_FIRST), c6})
	add_consistency_fact(t, &target, {n2, rdf.iri(RDF_REST), rdf.iri(RDF_NIL)})
	add_consistency_fact(t, &target, {x, type, c5})
	add_consistency_fact(t, &target, {x, type, c6})
	add_consistency_fact(t, &target, {rdf.iri("urn:nothing-instance"), type, rdf.iri(OWL_NOTHING)})
	property_group, pnode1, pnode2 := rdf.blank_node("all-disjoint-properties", rdf.Blank_Node_Scope(17)), rdf.blank_node("all-disjoint-properties-1", rdf.Blank_Node_Scope(17)), rdf.blank_node("all-disjoint-properties-2", rdf.Blank_Node_Scope(17))
	add_consistency_fact(t, &target, {property_group, type, rdf.iri(OWL_ALL_DISJOINT_PROPERTIES)})
	add_consistency_fact(t, &target, {property_group, rdf.iri(OWL_MEMBERS), pnode1})
	add_consistency_fact(t, &target, {pnode1, rdf.iri(RDF_FIRST), p3})
	add_consistency_fact(t, &target, {pnode1, rdf.iri(RDF_REST), pnode2})
	add_consistency_fact(t, &target, {pnode2, rdf.iri(RDF_FIRST), p4})
	add_consistency_fact(t, &target, {pnode2, rdf.iri(RDF_REST), rdf.iri(RDF_NIL)})
	add_consistency_fact(t, &target, {s, p3, o})
	add_consistency_fact(t, &target, {s, p4, o})
	negative_individual, negative_value := rdf.blank_node("negative-individual", rdf.Blank_Node_Scope(18)), rdf.blank_node("negative-value", rdf.Blank_Node_Scope(18))
	add_consistency_fact(t, &target, {negative_individual, type, rdf.iri(OWL_NEGATIVE_PROPERTY_ASSERTION)})
	add_consistency_fact(t, &target, {negative_individual, rdf.iri(OWL_SOURCE_INDIVIDUAL), a})
	add_consistency_fact(t, &target, {negative_individual, rdf.iri(OWL_ASSERTION_PROPERTY), p5})
	add_consistency_fact(t, &target, {negative_individual, rdf.iri(OWL_TARGET_INDIVIDUAL), b})
	add_consistency_fact(t, &target, {a, p5, b})
	add_consistency_fact(t, &target, {negative_value, type, rdf.iri(OWL_NEGATIVE_PROPERTY_ASSERTION)})
	add_consistency_fact(t, &target, {negative_value, rdf.iri(OWL_SOURCE_INDIVIDUAL), a})
	add_consistency_fact(t, &target, {negative_value, rdf.iri(OWL_ASSERTION_PROPERTY), p6})
	add_consistency_fact(t, &target, {negative_value, rdf.iri(OWL_TARGET_VALUE), rdf.literal("blocked")})
	add_consistency_fact(t, &target, {a, p6, rdf.literal("blocked")})
	different_group, dnode1, dnode2 := rdf.blank_node("all-different", rdf.Blank_Node_Scope(19)), rdf.blank_node("all-different-1", rdf.Blank_Node_Scope(19)), rdf.blank_node("all-different-2", rdf.Blank_Node_Scope(19))
	add_consistency_fact(t, &target, {different_group, type, rdf.iri(OWL_ALL_DIFFERENT)})
	add_consistency_fact(t, &target, {different_group, rdf.iri(OWL_MEMBERS), dnode1})
	add_consistency_fact(t, &target, {dnode1, rdf.iri(RDF_FIRST), u})
	add_consistency_fact(t, &target, {dnode1, rdf.iri(RDF_REST), dnode2})
	add_consistency_fact(t, &target, {dnode2, rdf.iri(RDF_FIRST), u})
	add_consistency_fact(t, &target, {dnode2, rdf.iri(RDF_REST), rdf.iri(RDF_NIL)})
	distinct_group, distinct_node1, distinct_node2 := rdf.blank_node("all-different-distinct", rdf.Blank_Node_Scope(20)), rdf.blank_node("all-different-distinct-1", rdf.Blank_Node_Scope(20)), rdf.blank_node("all-different-distinct-2", rdf.Blank_Node_Scope(20))
	add_consistency_fact(t, &target, {distinct_group, type, rdf.iri(OWL_ALL_DIFFERENT)})
	add_consistency_fact(t, &target, {distinct_group, rdf.iri(OWL_DISTINCT_MEMBERS), distinct_node1})
	add_consistency_fact(t, &target, {distinct_node1, rdf.iri(RDF_FIRST), u})
	add_consistency_fact(t, &target, {distinct_node1, rdf.iri(RDF_REST), distinct_node2})
	add_consistency_fact(t, &target, {distinct_node2, rdf.iri(RDF_FIRST), u})
	add_consistency_fact(t, &target, {distinct_node2, rdf.iri(RDF_REST), rdf.iri(RDF_NIL)})
	add_consistency_fact(t, &target, {p1, rdf.iri(OWL_PROPERTY_DISJOINT_WITH), p2})
	add_consistency_fact(t, &target, {s, p1, o})
	add_consistency_fact(t, &target, {s, p2, o})
	add_consistency_fact(t, &target, {irreflexive, type, rdf.iri(OWL_IRREFLEXIVE_PROPERTY)})
	add_consistency_fact(t, &target, {irreflexive, irreflexive, irreflexive})
	add_consistency_fact(t, &target, {asymmetric, type, rdf.iri(OWL_ASYMMETRIC_PROPERTY)})
	add_consistency_fact(t, &target, {m, asymmetric, n})
	add_consistency_fact(t, &target, {n, asymmetric, m})
	max_zero, cardinality_subject := rdf.iri("urn:max-zero"), rdf.iri("urn:cardinality-subject")
	add_consistency_fact(t, &target, {max_zero, rdf.iri(OWL_MAX_CARDINALITY), rdf.typed_literal("0", XSD_NON_NEGATIVE_INTEGER)})
	add_consistency_fact(t, &target, {max_zero, rdf.iri(OWL_ON_PROPERTY), p7})
	add_consistency_fact(t, &target, {cardinality_subject, type, max_zero})
	add_consistency_fact(t, &target, {cardinality_subject, p7, rdf.literal("forbidden")})

	result := materialize_checked(&profile, &target, &report)
	testing.expect_value(t, result.materialization.error, rule.Error_Code.None)
	testing.expect_value(t, result.consistency, Consistency_Error_Code.None)
	testing.expect(t, !result.consistent)
	testing.expect(t, has_kind(&report, .Same_As_Different_From))
	testing.expect(t, has_kind(&report, .Disjoint_Classes))
	testing.expect(t, has_kind(&report, .Complement_Classes))
	testing.expect(t, has_kind(&report, .All_Disjoint_Classes))
	testing.expect(t, has_kind(&report, .All_Disjoint_Properties))
	testing.expect(t, has_kind(&report, .Negative_Property_Assertion))
	testing.expect(t, has_kind(&report, .All_Different))
	testing.expect_value(t, count_kind(&report, .All_Different), 2)
	testing.expect(t, has_kind(&report, .Nothing_Instance))
	testing.expect(t, has_kind(&report, .Disjoint_Properties))
	testing.expect(t, has_kind(&report, .Irreflexive_Property))
	testing.expect(t, has_kind(&report, .Asymmetric_Property))
	testing.expect(t, has_kind(&report, .Max_Cardinality_Zero))
	for index in 0..<violation_count(&report) {
		violation, found := violation_at(&report, index)
		testing.expect(t, found && (violation.kind == .Nothing_Instance || violation.support_count >= 2))
		if found && (violation.kind == .All_Disjoint_Classes || violation.kind == .All_Disjoint_Properties) do testing.expect_value(t, violation.support_count, 4)
		if found && violation.kind == .Negative_Property_Assertion do testing.expect_value(t, violation.support_count, 5)
		if found && violation.kind == .Max_Cardinality_Zero do testing.expect_value(t, violation.support_count, 4)
	}
}

@(test)
test_consistency_violation_limit_clears_report_explicitly :: proc(t: ^testing.T) {
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
	add_consistency_fact(t, &target, {rdf.iri("urn:a"), rdf.iri(OWL_SAME_AS), rdf.iri("urn:b")})
	add_consistency_fact(t, &target, {rdf.iri("urn:a"), rdf.iri(OWL_DIFFERENT_FROM), rdf.iri("urn:b")})
	add_consistency_fact(t, &target, {rdf.iri("urn:C1"), rdf.iri(OWL_DISJOINT_WITH), rdf.iri("urn:C2")})
	add_consistency_fact(t, &target, {rdf.iri("urn:x"), rdf.iri(rdfs.RDF_TYPE), rdf.iri("urn:C1")})
	add_consistency_fact(t, &target, {rdf.iri("urn:x"), rdf.iri(rdfs.RDF_TYPE), rdf.iri("urn:C2")})
	materialized := materialize(&profile, &target)
	testing.expect_value(t, materialized.error, rule.Error_Code.None)
	check_error := check_consistency(&profile, &target, &report, {max_violations = 1})
	testing.expect_value(t, check_error, Consistency_Error_Code.Violation_Limit)
	testing.expect_value(t, violation_count(&report), 0)
}

@(test)
test_all_disjoint_malformed_list_clears_report_explicitly :: proc(t: ^testing.T) {
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

	add_consistency_fact(t, &target, {rdf.iri("urn:a"), rdf.iri(OWL_SAME_AS), rdf.iri("urn:b")})
	add_consistency_fact(t, &target, {rdf.iri("urn:a"), rdf.iri(OWL_DIFFERENT_FROM), rdf.iri("urn:b")})
	group, node := rdf.blank_node("malformed-disjoint", rdf.Blank_Node_Scope(16)), rdf.blank_node("malformed-members", rdf.Blank_Node_Scope(16))
	add_consistency_fact(t, &target, {group, rdf.iri(rdfs.RDF_TYPE), rdf.iri(OWL_ALL_DISJOINT_CLASSES)})
	add_consistency_fact(t, &target, {group, rdf.iri(OWL_MEMBERS), node})
	add_consistency_fact(t, &target, {node, rdf.iri(RDF_FIRST), rdf.iri("urn:C")})
	before := store.fact_count(&target)
	check_error := check_consistency(&profile, &target, &report)
	testing.expect_value(t, check_error, Consistency_Error_Code.List_Error)
	testing.expect_value(t, violation_count(&report), 0)
	testing.expect_value(t, store.fact_count(&target), before)
}
