package owlrl

import "core:testing"
import rdf "odin-rdf:rdf"
import rdfs "../rdfs"
import rule "../rule"
import store "../store"
import term "../term"

@(private) add_all_fact :: proc(t: ^testing.T, target: ^store.Store, triple: rdf.Triple) {
	added, error := store.insert_triple(target, triple)
	testing.expect(t, added)
	testing.expect_value(t, error, store.Error_Code.None)
}

@(private) has_all_fact :: proc(target: ^store.Store, triple: rdf.Triple) -> bool {
	fact := store.Fact{
		subject = term.id_for(&target.dictionary, triple.subject),
		predicate = term.id_for(&target.dictionary, triple.predicate),
		object = term.id_for(&target.dictionary, triple.object),
	}
	return fact.subject != term.INVALID_TERM_ID && fact.predicate != term.INVALID_TERM_ID && fact.object != term.INVALID_TERM_ID && store.contains(target, fact)
}

@(private) closure_derivation_for :: proc(profile: ^Profile, fact_id: store.Fact_ID) -> (Closure_Derivation_View, bool) {
	for index in 0..<closure_derivation_count(profile) {
		derivation, found := closure_derivation_at(profile, index)
		if found && derivation.fact_id == fact_id do return derivation, true
	}
	return {}, false
}

@(private) closure_supports :: proc(derivation: Closure_Derivation_View, fact_id: store.Fact_ID) -> bool {
	for support in derivation.supports do if support == fact_id do return true
	return false
}

@(test)
test_materialize_all_reaches_one_fixpoint_across_every_supported_list_phase :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)

	choice, right, intersection, union_class, entity := rdf.iri("urn:Choice"), rdf.iri("urn:Right"), rdf.iri("urn:Intersection"), rdf.iri("urn:Union"), rdf.iri("urn:Entity")
	a, b, c, z := rdf.iri("urn:a"), rdf.iri("urn:b"), rdf.iri("urn:c"), rdf.iri("urn:z")
	p1, p2, chain, super := rdf.iri("urn:p1"), rdf.iri("urn:p2"), rdf.iri("urn:chain"), rdf.iri("urn:super")
	one_head := rdf.blank_node("one", rdf.Blank_Node_Scope(31))
	intersection_head, intersection_tail := rdf.blank_node("intersection", rdf.Blank_Node_Scope(31)), rdf.blank_node("intersection-tail", rdf.Blank_Node_Scope(31))
	union_head := rdf.blank_node("union", rdf.Blank_Node_Scope(31))
	chain_head, chain_tail := rdf.blank_node("chain", rdf.Blank_Node_Scope(31)), rdf.blank_node("chain-tail", rdf.Blank_Node_Scope(31))

	add_all_fact(t, &target, {choice, rdf.iri(OWL_ONE_OF), one_head})
	add_all_fact(t, &target, {one_head, rdf.iri(RDF_FIRST), a})
	add_all_fact(t, &target, {one_head, rdf.iri(RDF_REST), rdf.iri(RDF_NIL)})
	add_all_fact(t, &target, {intersection, rdf.iri(OWL_INTERSECTION_OF), intersection_head})
	add_all_fact(t, &target, {intersection_head, rdf.iri(RDF_FIRST), choice})
	add_all_fact(t, &target, {intersection_head, rdf.iri(RDF_REST), intersection_tail})
	add_all_fact(t, &target, {intersection_tail, rdf.iri(RDF_FIRST), right})
	add_all_fact(t, &target, {intersection_tail, rdf.iri(RDF_REST), rdf.iri(RDF_NIL)})
	add_all_fact(t, &target, {union_class, rdf.iri(OWL_UNION_OF), union_head})
	add_all_fact(t, &target, {union_head, rdf.iri(RDF_FIRST), intersection})
	add_all_fact(t, &target, {union_head, rdf.iri(RDF_REST), rdf.iri(RDF_NIL)})
	add_all_fact(t, &target, {union_class, rdf.iri(rdfs.RDFS_SUBCLASS), entity})
	add_all_fact(t, &target, {a, rdf.iri(rdfs.RDF_TYPE), right})
	add_all_fact(t, &target, {z, rdf.iri(rdfs.RDF_TYPE), intersection})
	add_all_fact(t, &target, {chain, rdf.iri(OWL_PROPERTY_CHAIN_AXIOM), chain_head})
	add_all_fact(t, &target, {chain_head, rdf.iri(RDF_FIRST), p1})
	add_all_fact(t, &target, {chain_head, rdf.iri(RDF_REST), chain_tail})
	add_all_fact(t, &target, {chain_tail, rdf.iri(RDF_FIRST), p2})
	add_all_fact(t, &target, {chain_tail, rdf.iri(RDF_REST), rdf.iri(RDF_NIL)})
	add_all_fact(t, &target, {chain, rdf.iri(rdfs.RDFS_SUBPROPERTY), super})
	add_all_fact(t, &target, {a, p1, b})
	add_all_fact(t, &target, {b, p2, c})

	result := materialize_all(&profile, &target, {max_list_items = 4, max_path_states = 4})
	testing.expect_value(t, result.error, Materialize_All_Error_Code.None)
	testing.expect(t, result.rounds > 1)
	testing.expect(t, has_all_fact(&target, {a, rdf.iri(rdfs.RDF_TYPE), choice}))
	testing.expect(t, has_all_fact(&target, {a, rdf.iri(rdfs.RDF_TYPE), intersection}))
	testing.expect(t, has_all_fact(&target, {a, rdf.iri(rdfs.RDF_TYPE), union_class}))
	testing.expect(t, has_all_fact(&target, {a, rdf.iri(rdfs.RDF_TYPE), entity}))
	testing.expect(t, has_all_fact(&target, {z, rdf.iri(rdfs.RDF_TYPE), choice}))
	testing.expect(t, has_all_fact(&target, {z, rdf.iri(rdfs.RDF_TYPE), right}))
	testing.expect(t, has_all_fact(&target, {a, chain, c}))
	testing.expect(t, has_all_fact(&target, {a, super, c}))
	testing.expect_value(t, rule.derivation_count(&profile.materializer), 0)
	testing.expect_value(t, closure_derivation_count(&profile), result.inferred_facts)

	one_of_fact := store.id_for_fact(&target, {subject = term.id_for(&target.dictionary, a), predicate = term.id_for(&target.dictionary, rdf.iri(rdfs.RDF_TYPE)), object = term.id_for(&target.dictionary, choice)})
	one_of_derivation, one_of_found := closure_derivation_for(&profile, one_of_fact)
	testing.expect(t, one_of_found)
	testing.expect_value(t, one_of_derivation.rule_id, OWL_RL_CLS_OO)
	testing.expect(t, closure_supports(one_of_derivation, store.id_for_fact(&target, {subject = term.id_for(&target.dictionary, choice), predicate = term.id_for(&target.dictionary, rdf.iri(OWL_ONE_OF)), object = term.id_for(&target.dictionary, one_head)})))
	testing.expect(t, closure_supports(one_of_derivation, store.id_for_fact(&target, {subject = term.id_for(&target.dictionary, one_head), predicate = term.id_for(&target.dictionary, rdf.iri(RDF_FIRST)), object = term.id_for(&target.dictionary, a)})))
	testing.expect(t, closure_supports(one_of_derivation, store.id_for_fact(&target, {subject = term.id_for(&target.dictionary, one_head), predicate = term.id_for(&target.dictionary, rdf.iri(RDF_REST)), object = term.id_for(&target.dictionary, rdf.iri(RDF_NIL))})))

	intersection_fact := store.id_for_fact(&target, {subject = term.id_for(&target.dictionary, a), predicate = term.id_for(&target.dictionary, rdf.iri(rdfs.RDF_TYPE)), object = term.id_for(&target.dictionary, intersection)})
	intersection_derivation, intersection_found := closure_derivation_for(&profile, intersection_fact)
	testing.expect(t, intersection_found)
	testing.expect_value(t, intersection_derivation.rule_id, OWL_RL_CLS_INT1)
	intersection_reverse_fact := store.id_for_fact(&target, {subject = term.id_for(&target.dictionary, z), predicate = term.id_for(&target.dictionary, rdf.iri(rdfs.RDF_TYPE)), object = term.id_for(&target.dictionary, choice)})
	intersection_reverse_derivation, intersection_reverse_found := closure_derivation_for(&profile, intersection_reverse_fact)
	testing.expect(t, intersection_reverse_found)
	testing.expect_value(t, intersection_reverse_derivation.rule_id, OWL_RL_CLS_INT2)
	union_fact := store.id_for_fact(&target, {subject = term.id_for(&target.dictionary, a), predicate = term.id_for(&target.dictionary, rdf.iri(rdfs.RDF_TYPE)), object = term.id_for(&target.dictionary, union_class)})
	union_derivation, union_found := closure_derivation_for(&profile, union_fact)
	testing.expect(t, union_found)
	testing.expect_value(t, union_derivation.rule_id, OWL_RL_CLS_UNI)
	entity_fact := store.id_for_fact(&target, {subject = term.id_for(&target.dictionary, a), predicate = term.id_for(&target.dictionary, rdf.iri(rdfs.RDF_TYPE)), object = term.id_for(&target.dictionary, entity)})
	entity_derivation, entity_found := closure_derivation_for(&profile, entity_fact)
	testing.expect(t, entity_found)
	testing.expect_value(t, entity_derivation.rule_id, rdfs.RDFS_SC)

	chain_fact := store.id_for_fact(&target, {subject = term.id_for(&target.dictionary, a), predicate = term.id_for(&target.dictionary, chain), object = term.id_for(&target.dictionary, c)})
	chain_derivation, chain_found := closure_derivation_for(&profile, chain_fact)
	testing.expect(t, chain_found)
	testing.expect_value(t, chain_derivation.rule_id, OWL_RL_PRP_SPO2)
	testing.expect(t, closure_supports(chain_derivation, store.id_for_fact(&target, {subject = term.id_for(&target.dictionary, a), predicate = term.id_for(&target.dictionary, p1), object = term.id_for(&target.dictionary, b)})))
	testing.expect(t, closure_supports(chain_derivation, store.id_for_fact(&target, {subject = term.id_for(&target.dictionary, b), predicate = term.id_for(&target.dictionary, p2), object = term.id_for(&target.dictionary, c)})))
}

@(test)
test_materialize_all_retains_zero_premise_annotation_axiom_provenance :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)

	result := materialize_all(&profile, &target)
	testing.expect_value(t, result.error, Materialize_All_Error_Code.None)
	fact := store.Fact{subject = profile.terms.annotation_properties[0], predicate = profile.terms.rdf_type, object = profile.terms.annotation_property}
	fact_id := store.id_for_fact(&target, fact)
	derivation, found := closure_derivation_for(&profile, fact_id)
	testing.expect(t, found)
	testing.expect_value(t, derivation.rule_id, OWL_RL_PRP_AP)
	testing.expect_value(t, len(derivation.supports), 0)
}

@(test)
test_materialize_all_keeps_every_dynamic_phase_transactional :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)

	choice, one_head, broken_head := rdf.iri("urn:Choice"), rdf.blank_node("one", rdf.Blank_Node_Scope(32)), rdf.blank_node("broken", rdf.Blank_Node_Scope(32))
	add_all_fact(t, &target, {choice, rdf.iri(OWL_ONE_OF), one_head})
	add_all_fact(t, &target, {one_head, rdf.iri(RDF_FIRST), rdf.iri("urn:a")})
	add_all_fact(t, &target, {one_head, rdf.iri(RDF_REST), rdf.iri(RDF_NIL)})
	add_all_fact(t, &target, {rdf.iri("urn:BrokenUnion"), rdf.iri(OWL_UNION_OF), broken_head})
	add_all_fact(t, &target, {broken_head, rdf.iri(RDF_FIRST), rdf.iri("urn:Class")})
	before := store.fact_count(&target)

	result := materialize_all(&profile, &target)
	testing.expect_value(t, result.error, Materialize_All_Error_Code.List_Error)
	testing.expect_value(t, result.list_error, List_Error_Code.Missing_Rest)
	testing.expect_value(t, store.fact_count(&target), before)
	testing.expect(t, !has_all_fact(&target, {rdf.iri("urn:a"), rdf.iri(rdfs.RDF_TYPE), choice}))
}

@(test)
test_materialize_all_reports_path_limit_without_committing_other_closure_work :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)

	chain, p1, p2 := rdf.iri("urn:chain"), rdf.iri("urn:p1"), rdf.iri("urn:p2")
	head, tail := rdf.blank_node("chain", rdf.Blank_Node_Scope(33)), rdf.blank_node("chain-tail", rdf.Blank_Node_Scope(33))
	add_all_fact(t, &target, {chain, rdf.iri(OWL_PROPERTY_CHAIN_AXIOM), head})
	add_all_fact(t, &target, {head, rdf.iri(RDF_FIRST), p1})
	add_all_fact(t, &target, {head, rdf.iri(RDF_REST), tail})
	add_all_fact(t, &target, {tail, rdf.iri(RDF_FIRST), p2})
	add_all_fact(t, &target, {tail, rdf.iri(RDF_REST), rdf.iri(RDF_NIL)})
	add_all_fact(t, &target, {rdf.iri("urn:a"), p1, rdf.iri("urn:b")})
	add_all_fact(t, &target, {rdf.iri("urn:x"), p1, rdf.iri("urn:y")})
	before := store.fact_count(&target)

	result := materialize_all(&profile, &target, {max_path_states = 1})
	testing.expect_value(t, result.error, Materialize_All_Error_Code.Path_State_Limit)
	testing.expect_value(t, store.fact_count(&target), before)
}

@(test)
test_materialize_all_clears_stale_focused_provenance :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)

	add_all_fact(t, &target, {rdf.iri("urn:A"), rdf.iri(OWL_EQUIVALENT_CLASS), rdf.iri("urn:B")})
	focused := materialize(&profile, &target)
	testing.expect_value(t, focused.error, rule.Error_Code.None)
	testing.expect(t, rule.derivation_count(&profile.materializer) > 0)

	complete := materialize_all(&profile, &target)
	testing.expect_value(t, complete.error, Materialize_All_Error_Code.None)
	testing.expect_value(t, rule.derivation_count(&profile.materializer), 0)
}

@(test)
test_materialize_all_keeps_last_successful_closure_provenance_on_failure :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)

	choice, head := rdf.iri("urn:Choice"), rdf.blank_node("one", rdf.Blank_Node_Scope(34))
	add_all_fact(t, &target, {choice, rdf.iri(OWL_ONE_OF), head})
	add_all_fact(t, &target, {head, rdf.iri(RDF_FIRST), rdf.iri("urn:a")})
	add_all_fact(t, &target, {head, rdf.iri(RDF_REST), rdf.iri(RDF_NIL)})
	success := materialize_all(&profile, &target)
	testing.expect_value(t, success.error, Materialize_All_Error_Code.None)
	before := closure_derivation_count(&profile)
	testing.expect(t, before > 0)

	broken := rdf.blank_node("broken", rdf.Blank_Node_Scope(34))
	add_all_fact(t, &target, {rdf.iri("urn:Broken"), rdf.iri(OWL_UNION_OF), broken})
	add_all_fact(t, &target, {broken, rdf.iri(RDF_FIRST), rdf.iri("urn:Class")})
	failure := materialize_all(&profile, &target)
	testing.expect_value(t, failure.error, Materialize_All_Error_Code.List_Error)
	testing.expect_value(t, closure_derivation_count(&profile), before)
}
