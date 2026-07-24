package owlrl

import "core:testing"
import rdf "odin-rdf:rdf"
import rdfs "../rdfs"
import rule "../rule"
import store "../store"
import term "../term"

@(private) add :: proc(t: ^testing.T, target: ^store.Store, triple: rdf.Triple) {
	added, error := store.insert_triple(target, triple)
	testing.expect(t, added)
	testing.expect_value(t, error, store.Error_Code.None)
}

@(private) has :: proc(target: ^store.Store, triple: rdf.Triple) -> bool {
	fact := store.Fact{
		subject = term.id_for(&target.dictionary, triple.subject),
		predicate = term.id_for(&target.dictionary, triple.predicate),
		object = term.id_for(&target.dictionary, triple.object),
	}
	return fact.subject != term.INVALID_TERM_ID && fact.predicate != term.INVALID_TERM_ID && fact.object != term.INVALID_TERM_ID && store.contains(target, fact)
}

@(test)
test_equivalence_rules_compose_with_rdfs_core_at_one_fixpoint :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)

	type := rdf.iri(rdfs.RDF_TYPE)
	subclass := rdf.iri(rdfs.RDFS_SUBCLASS)
	domain := rdf.iri(rdfs.RDFS_DOMAIN_IRI)
	equivalent_class := rdf.iri(OWL_EQUIVALENT_CLASS)
	equivalent_property := rdf.iri(OWL_EQUIVALENT_PROPERTY)
	person, agent, entity := rdf.iri("urn:Person"), rdf.iri("urn:Agent"), rdf.iri("urn:Entity")
	p1, p2 := rdf.iri("urn:p1"), rdf.iri("urn:p2")
	ada := rdf.iri("urn:ada")

	add(t, &target, {person, equivalent_class, agent})
	add(t, &target, {agent, subclass, entity})
	add(t, &target, {ada, type, person})
	add(t, &target, {p1, equivalent_property, p2})
	add(t, &target, {p2, domain, agent})
	add(t, &target, {ada, p1, rdf.literal("value")})

	result := materialize(&profile, &target)
	testing.expect_value(t, result.error, rule.Error_Code.None)
	testing.expect(t, has(&target, {ada, type, agent}))
	testing.expect(t, has(&target, {ada, type, entity}))
	testing.expect(t, has(&target, {ada, p2, rdf.literal("value")}))
}

@(test)
test_builtin_annotation_property_axioms_have_zero_support :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)

	result := materialize(&profile, &target)
	testing.expect_value(t, result.error, rule.Error_Code.None)
	for annotation_property in profile.terms.annotation_properties {
		fact := store.Fact{subject = annotation_property, predicate = profile.terms.rdf_type, object = profile.terms.annotation_property}
		testing.expect(t, store.contains(&target, fact))
		fact_id := store.id_for_fact(&target, fact)
		found := false
		for index in 0..<rule.derivation_count(&profile.materializer) {
			derivation, derivation_found := rule.derivation_at(&profile.materializer, index)
			if !derivation_found || derivation.fact_id != fact_id do continue
			found = true
			testing.expect_value(t, derivation.rule_id, OWL_RL_PRP_AP)
			testing.expect_value(t, len(derivation.supports), 0)
			break
		}
		testing.expect(t, found)
	}
}

@(test)
test_owl_rl_datatype_axioms_have_zero_support :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)

	result := materialize(&profile, &target)
	testing.expect_value(t, result.error, rule.Error_Code.None)
	testing.expect_value(t, len(profile.terms.owl_rl_datatypes), 32)
	for datatype in profile.terms.owl_rl_datatypes {
		fact := store.Fact{subject = datatype, predicate = profile.terms.rdf_type, object = profile.terms.rdfs_datatype}
		testing.expect(t, store.contains(&target, fact))
		fact_id := store.id_for_fact(&target, fact)
		found := false
		for index in 0..<rule.derivation_count(&profile.materializer) {
			derivation, derivation_found := rule.derivation_at(&profile.materializer, index)
			if !derivation_found || derivation.fact_id != fact_id do continue
			found = true
			testing.expect_value(t, derivation.rule_id, OWL_RL_DT_TYPE1)
			testing.expect_value(t, len(derivation.supports), 0)
			break
		}
		testing.expect(t, found)
	}
}

@(test)
test_owl_rl_builtin_class_axioms_have_zero_support :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)

	result := materialize(&profile, &target)
	testing.expect_value(t, result.error, rule.Error_Code.None)
	thing_fact := store.Fact{subject = profile.terms.owl_thing, predicate = profile.terms.rdf_type, object = profile.terms.owl_class}
	nothing_fact := store.Fact{subject = profile.terms.owl_nothing, predicate = profile.terms.rdf_type, object = profile.terms.owl_class}
	testing.expect(t, store.contains(&target, thing_fact))
	testing.expect(t, store.contains(&target, nothing_fact))
	thing_id := store.id_for_fact(&target, thing_fact)
	nothing_id := store.id_for_fact(&target, nothing_fact)
	thing_found, nothing_found := false, false
	for index in 0..<rule.derivation_count(&profile.materializer) {
		derivation, found := rule.derivation_at(&profile.materializer, index)
		if !found do continue
		if derivation.fact_id == thing_id {
			thing_found = true
			testing.expect_value(t, derivation.rule_id, OWL_RL_CLS_THING)
			testing.expect_value(t, len(derivation.supports), 0)
		}
		if derivation.fact_id == nothing_id {
			nothing_found = true
			testing.expect_value(t, derivation.rule_id, OWL_RL_CLS_NOTHING1)
			testing.expect_value(t, len(derivation.supports), 0)
		}
	}
	testing.expect(t, thing_found)
	testing.expect(t, nothing_found)
}

@(test)
test_object_property_rules_compose_at_one_fixpoint :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)

	type := rdf.iri(rdfs.RDF_TYPE)
	p1, p2, p3 := rdf.iri("urn:p1"), rdf.iri("urn:p2"), rdf.iri("urn:p3")
	a, b, c := rdf.iri("urn:a"), rdf.iri("urn:b"), rdf.iri("urn:c")
	add(t, &target, {p1, rdf.iri(OWL_INVERSE_OF), p2})
	add(t, &target, {p1, type, rdf.iri(OWL_TRANSITIVE_PROPERTY)})
	add(t, &target, {p2, type, rdf.iri(OWL_SYMMETRIC_PROPERTY)})
	add(t, &target, {p2, rdf.iri(OWL_EQUIVALENT_PROPERTY), p3})
	add(t, &target, {a, p1, b})
	add(t, &target, {b, p1, c})

	result := materialize(&profile, &target)
	testing.expect_value(t, result.error, rule.Error_Code.None)
	testing.expect(t, has(&target, {a, p1, c}))
	testing.expect(t, has(&target, {b, p2, a}))
	testing.expect(t, has(&target, {a, p2, b}))
	testing.expect(t, has(&target, {c, p2, a}))
	testing.expect(t, has(&target, {a, p2, c}))
	testing.expect(t, has(&target, {a, p3, c}))
}

@(test)
test_reversing_property_rules_skip_literal_subject_heads :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)

	p1, p2 := rdf.iri("urn:p1"), rdf.iri("urn:p2")
	source, literal := rdf.iri("urn:source"), rdf.literal("literal object")
	add(t, &target, {p1, rdf.iri(OWL_INVERSE_OF), p2})
	add(t, &target, {p2, rdf.iri(rdfs.RDF_TYPE), rdf.iri(OWL_SYMMETRIC_PROPERTY)})
	add(t, &target, {source, p1, literal})
	add(t, &target, {source, p2, literal})
	result := materialize(&profile, &target)
	testing.expect_value(t, result.error, rule.Error_Code.None)
	testing.expect(t, !has(&target, {literal, p2, source}))
	testing.expect(t, !has(&target, {literal, p1, source}))
}

@(test)
test_generalized_materialization_retains_literal_subject_heads :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)

	p1, p2 := rdf.iri("urn:p1"), rdf.iri("urn:p2")
	source, literal := rdf.iri("urn:source"), rdf.literal("literal object")
	add(t, &target, {p1, rdf.iri(OWL_INVERSE_OF), p2})
	add(t, &target, {source, p1, literal})

	result := materialize_generalized(&profile, &target)
	testing.expect_value(t, result.error, rule.Error_Code.None)
	testing.expect(t, has(&target, {literal, p2, source}))
}

@(test)
test_schema_domain_and_range_rules_drive_rdfs_instance_closure :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)

	subclass := rdf.iri(rdfs.RDFS_SUBCLASS)
	subproperty := rdf.iri(rdfs.RDFS_SUBPROPERTY)
	domain := rdf.iri(rdfs.RDFS_DOMAIN_IRI)
	range := rdf.iri(rdfs.RDFS_RANGE_IRI)
	type := rdf.iri(rdfs.RDF_TYPE)
	p1, p2 := rdf.iri("urn:p1"), rdf.iri("urn:p2")
	c1, c2 := rdf.iri("urn:C1"), rdf.iri("urn:C2")
	x, y := rdf.iri("urn:x"), rdf.iri("urn:y")
	add(t, &target, {p1, subproperty, p2})
	add(t, &target, {p2, domain, c1})
	add(t, &target, {p2, range, c1})
	add(t, &target, {c1, subclass, c2})
	add(t, &target, {x, p1, y})

	result := materialize(&profile, &target)
	testing.expect_value(t, result.error, rule.Error_Code.None)
	testing.expect(t, has(&target, {p1, domain, c1}))
	testing.expect(t, has(&target, {p1, range, c1}))
	testing.expect(t, has(&target, {p2, domain, c2}))
	testing.expect(t, has(&target, {p2, range, c2}))
	testing.expect(t, has(&target, {p1, domain, c2}))
	testing.expect(t, has(&target, {p1, range, c2}))
	testing.expect(t, has(&target, {x, type, c1}))
	testing.expect(t, has(&target, {x, type, c2}))
	testing.expect(t, has(&target, {y, type, c1}))
	testing.expect(t, has(&target, {y, type, c2}))
}

@(test)
test_value_restriction_rules_handle_forward_reverse_and_thing_cases :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)

	type := rdf.iri(rdfs.RDF_TYPE)
	p := rdf.iri("urn:p")
	has_value, some_value, some_thing, all_value :=
		rdf.iri("urn:HasValue"), rdf.iri("urn:SomeValue"), rdf.iri("urn:SomeThing"), rdf.iri("urn:AllValue")
	target_class, all_target := rdf.iri("urn:Target"), rdf.iri("urn:AllTarget")
	alice, bob, charlie := rdf.iri("urn:alice"), rdf.iri("urn:bob"), rdf.iri("urn:charlie")
	object := rdf.iri("urn:object")
	literal := rdf.literal("fixed")
	add(t, &target, {has_value, rdf.iri(OWL_HAS_VALUE), literal})
	add(t, &target, {has_value, rdf.iri(OWL_ON_PROPERTY), p})
	add(t, &target, {alice, type, has_value})
	add(t, &target, {bob, p, literal})
	add(t, &target, {some_value, rdf.iri(OWL_SOME_VALUES_FROM), target_class})
	add(t, &target, {some_value, rdf.iri(OWL_ON_PROPERTY), p})
	add(t, &target, {charlie, p, object})
	add(t, &target, {object, type, target_class})
	add(t, &target, {some_thing, rdf.iri(OWL_SOME_VALUES_FROM), rdf.iri(OWL_THING)})
	add(t, &target, {some_thing, rdf.iri(OWL_ON_PROPERTY), p})
	add(t, &target, {bob, p, rdf.literal("any value")})
	add(t, &target, {all_value, rdf.iri(OWL_ALL_VALUES_FROM), all_target})
	add(t, &target, {all_value, rdf.iri(OWL_ON_PROPERTY), p})
	add(t, &target, {alice, type, all_value})
	add(t, &target, {alice, p, object})

	result := materialize(&profile, &target)
	testing.expect_value(t, result.error, rule.Error_Code.None)
	testing.expect(t, has(&target, {alice, p, literal}))
	testing.expect(t, has(&target, {bob, type, has_value}))
	testing.expect(t, has(&target, {charlie, type, some_value}))
	testing.expect(t, has(&target, {bob, type, some_thing}))
	testing.expect(t, has(&target, {object, type, all_target}))
}

@(test)
test_has_self_rules_require_typed_boolean_true_and_compose_with_rdfs :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)

	restriction, p, super, a, b := rdf.iri("urn:Self"), rdf.iri("urn:self-p"), rdf.iri("urn:Super"), rdf.iri("urn:a"), rdf.iri("urn:b")
	true_value := rdf.typed_literal("true", XSD_BOOLEAN)
	add(t, &target, {restriction, rdf.iri(OWL_HAS_SELF), true_value})
	add(t, &target, {restriction, rdf.iri(OWL_ON_PROPERTY), p})
	add(t, &target, {restriction, rdf.iri(rdfs.RDFS_SUBCLASS), super})
	add(t, &target, {a, rdf.iri(rdfs.RDF_TYPE), restriction})
	add(t, &target, {b, p, b})
	add(t, &target, {rdf.iri("urn:Wrong"), rdf.iri(OWL_HAS_SELF), rdf.literal("true")})
	add(t, &target, {rdf.iri("urn:Wrong"), rdf.iri(OWL_ON_PROPERTY), p})
	add(t, &target, {rdf.iri("urn:c"), rdf.iri(rdfs.RDF_TYPE), rdf.iri("urn:Wrong")})

	result := materialize(&profile, &target)
	testing.expect_value(t, result.error, rule.Error_Code.None)
	testing.expect(t, has(&target, {a, p, a}))
	testing.expect(t, has(&target, {b, rdf.iri(rdfs.RDF_TYPE), restriction}))
	testing.expect(t, has(&target, {a, rdf.iri(rdfs.RDF_TYPE), super}))
	testing.expect(t, has(&target, {b, rdf.iri(rdfs.RDF_TYPE), super}))
	testing.expect(t, !has(&target, {rdf.iri("urn:c"), p, rdf.iri("urn:c")}))
}

@(test)
test_owl_class_schema_rules_emit_all_four_consequences :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)

	class := rdf.iri("urn:DeclaredClass")
	add(t, &target, {class, rdf.iri(rdfs.RDF_TYPE), rdf.iri(OWL_CLASS)})
	result := materialize(&profile, &target)
	testing.expect_value(t, result.error, rule.Error_Code.None)
	testing.expect(t, has(&target, {class, rdf.iri(rdfs.RDFS_SUBCLASS), class}))
	testing.expect(t, has(&target, {class, rdf.iri(OWL_EQUIVALENT_CLASS), class}))
	testing.expect(t, has(&target, {class, rdf.iri(rdfs.RDFS_SUBCLASS), rdf.iri(OWL_THING)}))
	testing.expect(t, has(&target, {rdf.iri(OWL_NOTHING), rdf.iri(rdfs.RDFS_SUBCLASS), class}))
}

@(test)
test_object_property_schema_rules_emit_both_consequences :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)

	p := rdf.iri("urn:property")
	add(t, &target, {p, rdf.iri(rdfs.RDF_TYPE), rdf.iri(OWL_OBJECT_PROPERTY)})
	result := materialize(&profile, &target)
	testing.expect_value(t, result.error, rule.Error_Code.None)
	testing.expect(t, has(&target, {p, rdf.iri(rdfs.RDFS_SUBPROPERTY), p}))
	testing.expect(t, has(&target, {p, rdf.iri(OWL_EQUIVALENT_PROPERTY), p}))
}

@(test)
test_datatype_property_schema_rules_emit_both_consequences :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)

	p := rdf.iri("urn:datatype-property")
	add(t, &target, {p, rdf.iri(rdfs.RDF_TYPE), rdf.iri(OWL_DATATYPE_PROPERTY)})
	result := materialize(&profile, &target)
	testing.expect_value(t, result.error, rule.Error_Code.None)
	testing.expect(t, has(&target, {p, rdf.iri(rdfs.RDFS_SUBPROPERTY), p}))
	testing.expect(t, has(&target, {p, rdf.iri(OWL_EQUIVALENT_PROPERTY), p}))
}

@(test)
test_all_values_from_skips_literal_subject_type_conclusion :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)

	restriction, target_class, p, subject := rdf.iri("urn:AllValue"), rdf.iri("urn:Target"), rdf.iri("urn:p"), rdf.iri("urn:subject")
	literal := rdf.literal("literal object")
	add(t, &target, {restriction, rdf.iri(OWL_ALL_VALUES_FROM), target_class})
	add(t, &target, {restriction, rdf.iri(OWL_ON_PROPERTY), p})
	add(t, &target, {subject, rdf.iri(rdfs.RDF_TYPE), restriction})
	add(t, &target, {subject, p, literal})
	result := materialize(&profile, &target)
	testing.expect_value(t, result.error, rule.Error_Code.None)
	testing.expect(t, !has(&target, {literal, rdf.iri(rdfs.RDF_TYPE), target_class}))
}

@(test)
test_schema_equivalence_rules_close_class_property_and_instance_views :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)

	subclass, subproperty, type := rdf.iri(rdfs.RDFS_SUBCLASS), rdf.iri(rdfs.RDFS_SUBPROPERTY), rdf.iri(rdfs.RDF_TYPE)
	equivalent_class, equivalent_property := rdf.iri(OWL_EQUIVALENT_CLASS), rdf.iri(OWL_EQUIVALENT_PROPERTY)
	a, b, x := rdf.iri("urn:A"), rdf.iri("urn:B"), rdf.iri("urn:x")
	p1, p2, s, o := rdf.iri("urn:p1"), rdf.iri("urn:p2"), rdf.iri("urn:s"), rdf.iri("urn:o")
	add(t, &target, {a, equivalent_class, b})
	add(t, &target, {p1, equivalent_property, p2})
	add(t, &target, {x, type, a})
	add(t, &target, {s, p1, o})

	result := materialize(&profile, &target)
	testing.expect_value(t, result.error, rule.Error_Code.None)
	testing.expect(t, has(&target, {a, subclass, b}))
	testing.expect(t, has(&target, {b, subclass, a}))
	testing.expect(t, has(&target, {p1, subproperty, p2}))
	testing.expect(t, has(&target, {p2, subproperty, p1}))
	testing.expect(t, has(&target, {x, type, b}))
	testing.expect(t, has(&target, {s, p2, o}))

	second: store.Store
	testing.expect_value(t, store.init(&second), store.Error_Code.None)
	defer store.destroy(&second)
	second_profile: Profile
	second_profile_error, second_store_error := init(&second_profile, &second)
	testing.expect_value(t, second_profile_error, Error_Code.None)
	testing.expect_value(t, second_store_error, store.Error_Code.None)
	defer destroy(&second_profile)
	add(t, &second, {a, subclass, b})
	add(t, &second, {b, subclass, a})
	add(t, &second, {p1, subproperty, p2})
	add(t, &second, {p2, subproperty, p1})
	second_result := materialize(&second_profile, &second)
	testing.expect_value(t, second_result.error, rule.Error_Code.None)
	testing.expect(t, has(&second, {a, equivalent_class, b}))
	testing.expect(t, has(&second, {p1, equivalent_property, p2}))
}

@(test)
test_restriction_schema_subsumption_rules_preserve_each_direction :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)

	subclass, subproperty, type := rdf.iri(rdfs.RDFS_SUBCLASS), rdf.iri(rdfs.RDFS_SUBPROPERTY), rdf.iri(rdfs.RDF_TYPE)
	p1, p2, q := rdf.iri("urn:p1"), rdf.iri("urn:p2"), rdf.iri("urn:q")
	child, parent, filler := rdf.iri("urn:Child"), rdf.iri("urn:Parent"), rdf.iri("urn:Filler")
	hv1, hv2 := rdf.iri("urn:HV1"), rdf.iri("urn:HV2")
	svf1, svf2, svf3, svf4 := rdf.iri("urn:SVF1"), rdf.iri("urn:SVF2"), rdf.iri("urn:SVF3"), rdf.iri("urn:SVF4")
	avf1, avf2, avf3, avf4 := rdf.iri("urn:AVF1"), rdf.iri("urn:AVF2"), rdf.iri("urn:AVF3"), rdf.iri("urn:AVF4")
	instance := rdf.iri("urn:instance")
	add(t, &target, {p1, subproperty, p2})
	add(t, &target, {child, subclass, parent})
	add(t, &target, {hv1, rdf.iri(OWL_HAS_VALUE), rdf.literal("v")})
	add(t, &target, {hv1, rdf.iri(OWL_ON_PROPERTY), p1})
	add(t, &target, {hv2, rdf.iri(OWL_HAS_VALUE), rdf.literal("v")})
	add(t, &target, {hv2, rdf.iri(OWL_ON_PROPERTY), p2})
	add(t, &target, {svf1, rdf.iri(OWL_SOME_VALUES_FROM), child})
	add(t, &target, {svf1, rdf.iri(OWL_ON_PROPERTY), q})
	add(t, &target, {svf2, rdf.iri(OWL_SOME_VALUES_FROM), parent})
	add(t, &target, {svf2, rdf.iri(OWL_ON_PROPERTY), q})
	add(t, &target, {svf3, rdf.iri(OWL_SOME_VALUES_FROM), filler})
	add(t, &target, {svf3, rdf.iri(OWL_ON_PROPERTY), p1})
	add(t, &target, {svf4, rdf.iri(OWL_SOME_VALUES_FROM), filler})
	add(t, &target, {svf4, rdf.iri(OWL_ON_PROPERTY), p2})
	add(t, &target, {avf1, rdf.iri(OWL_ALL_VALUES_FROM), child})
	add(t, &target, {avf1, rdf.iri(OWL_ON_PROPERTY), q})
	add(t, &target, {avf2, rdf.iri(OWL_ALL_VALUES_FROM), parent})
	add(t, &target, {avf2, rdf.iri(OWL_ON_PROPERTY), q})
	add(t, &target, {avf3, rdf.iri(OWL_ALL_VALUES_FROM), filler})
	add(t, &target, {avf3, rdf.iri(OWL_ON_PROPERTY), p1})
	add(t, &target, {avf4, rdf.iri(OWL_ALL_VALUES_FROM), filler})
	add(t, &target, {avf4, rdf.iri(OWL_ON_PROPERTY), p2})
	add(t, &target, {instance, type, hv1})

	result := materialize(&profile, &target)
	testing.expect_value(t, result.error, rule.Error_Code.None)
	testing.expect(t, has(&target, {hv1, subclass, hv2}))
	testing.expect(t, has(&target, {svf1, subclass, svf2}))
	testing.expect(t, has(&target, {svf3, subclass, svf4}))
	testing.expect(t, has(&target, {avf1, subclass, avf2}))
	testing.expect(t, has(&target, {avf4, subclass, avf3}))
	testing.expect(t, has(&target, {instance, type, hv2}))
}

@(test)
test_same_as_closure_replaces_subject_predicate_and_object :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)

	same_as := rdf.iri(OWL_SAME_AS)
	a, b, c := rdf.iri("urn:a"), rdf.iri("urn:b"), rdf.iri("urn:c")
	p, q := rdf.iri("urn:p"), rdf.iri("urn:q")
	o, o2 := rdf.iri("urn:o"), rdf.iri("urn:o2")
	add(t, &target, {a, same_as, b})
	add(t, &target, {b, same_as, c})
	add(t, &target, {p, same_as, q})
	add(t, &target, {o, same_as, o2})
	add(t, &target, {a, p, o})

	result := materialize(&profile, &target)
	testing.expect_value(t, result.error, rule.Error_Code.None)
	testing.expect(t, has(&target, {a, same_as, a}))
	testing.expect(t, has(&target, {p, same_as, p}))
	testing.expect(t, has(&target, {o, same_as, o}))
	testing.expect(t, has(&target, {b, same_as, a}))
	testing.expect(t, has(&target, {a, same_as, c}))
	testing.expect(t, has(&target, {c, p, o}))
	testing.expect(t, has(&target, {a, q, o}))
	testing.expect(t, has(&target, {a, p, o2}))
	testing.expect(t, has(&target, {c, q, o2}))
}

@(test)
test_same_as_literal_boundary_preserves_object_replacement_only :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)

	same_as, p, subject, object := rdf.iri(OWL_SAME_AS), rdf.iri("urn:p"), rdf.iri("urn:subject"), rdf.iri("urn:object")
	literal := rdf.literal("equal literal")
	add(t, &target, {object, same_as, literal})
	add(t, &target, {subject, p, object})
	add(t, &target, {subject, p, literal})
	result := materialize(&profile, &target)
	testing.expect_value(t, result.error, rule.Error_Code.None)
	testing.expect(t, has(&target, {subject, p, literal}))
	testing.expect(t, !has(&target, {literal, same_as, object}))
	testing.expect(t, !has(&target, {literal, same_as, literal}))
	testing.expect(t, !has(&target, {literal, p, object}))
}

@(test)
test_same_as_resource_limit_keeps_source_unchanged :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)
	add(t, &target, {rdf.iri("urn:a"), rdf.iri("urn:p"), rdf.iri("urn:b")})
	before := store.fact_count(&target)
	result := materialize(&profile, &target, {max_derivations = 1})
	testing.expect_value(t, result.error, rule.Error_Code.Max_Derivations)
	testing.expect_value(t, store.fact_count(&target), before)
}

@(test)
test_functional_properties_derive_equality_and_replacement :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)

	type, same_as := rdf.iri(rdfs.RDF_TYPE), rdf.iri(OWL_SAME_AS)
	functional, inverse_functional := rdf.iri("urn:functional"), rdf.iri("urn:inverse-functional")
	s, s1, s2, o1, o2 := rdf.iri("urn:s"), rdf.iri("urn:s1"), rdf.iri("urn:s2"), rdf.iri("urn:o1"), rdf.iri("urn:o2")
	marker, tag := rdf.iri("urn:marker"), rdf.iri("urn:tag")
	add(t, &target, {functional, type, rdf.iri(OWL_FUNCTIONAL_PROPERTY)})
	add(t, &target, {s, functional, o1})
	add(t, &target, {s, functional, o2})
	add(t, &target, {o1, marker, tag})
	add(t, &target, {inverse_functional, type, rdf.iri(OWL_INVERSE_FUNCTIONAL_PROPERTY)})
	add(t, &target, {s1, inverse_functional, o1})
	add(t, &target, {s2, inverse_functional, o1})

	result := materialize(&profile, &target)
	testing.expect_value(t, result.error, rule.Error_Code.None)
	testing.expect(t, has(&target, {o1, same_as, o2}))
	testing.expect(t, has(&target, {o2, marker, tag}))
	testing.expect(t, has(&target, {s1, same_as, s2}))
	testing.expect(t, has(&target, {s2, inverse_functional, o1}))
}

@(test)
test_functional_property_skips_literal_subject_equality_head :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)

	p, s := rdf.iri("urn:functional"), rdf.iri("urn:s")
	left, right := rdf.literal("left"), rdf.literal("right")
	add(t, &target, {p, rdf.iri(rdfs.RDF_TYPE), rdf.iri(OWL_FUNCTIONAL_PROPERTY)})
	add(t, &target, {s, p, left})
	add(t, &target, {s, p, right})
	result := materialize(&profile, &target)
	testing.expect_value(t, result.error, rule.Error_Code.None)
	testing.expect(t, !has(&target, {left, rdf.iri(OWL_SAME_AS), right}))
}

@(test)
test_max_cardinality_one_derives_representable_equality_only :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)

	restriction, property, subject := rdf.iri("urn:max-one"), rdf.iri("urn:max-one-property"), rdf.iri("urn:max-one-subject")
	left, right := rdf.iri("urn:max-one-left"), rdf.iri("urn:max-one-right")
	literal_left, literal_right := rdf.literal("left"), rdf.literal("right")
	add(t, &target, {restriction, rdf.iri(OWL_MAX_CARDINALITY), rdf.typed_literal("1", XSD_NON_NEGATIVE_INTEGER)})
	add(t, &target, {restriction, rdf.iri(OWL_ON_PROPERTY), property})
	add(t, &target, {subject, rdf.iri(rdfs.RDF_TYPE), restriction})
	add(t, &target, {subject, property, left})
	add(t, &target, {subject, property, right})
	add(t, &target, {subject, property, literal_left})
	add(t, &target, {subject, property, literal_right})

	result := materialize(&profile, &target)
	testing.expect_value(t, result.error, rule.Error_Code.None)
	testing.expect(t, has(&target, {left, rdf.iri(OWL_SAME_AS), right}))
	testing.expect(t, !has(&target, {literal_left, rdf.iri(OWL_SAME_AS), literal_right}))
}

@(test)
test_max_qualified_cardinality_one_derives_representable_equality_only :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)

	qualified, qualified_property, qualified_class, qualified_subject := rdf.iri("urn:max-qualified-one"), rdf.iri("urn:max-qualified-property"), rdf.iri("urn:max-qualified-class"), rdf.iri("urn:max-qualified-subject")
	qualified_left, qualified_right := rdf.iri("urn:max-qualified-left"), rdf.iri("urn:max-qualified-right")
	add(t, &target, {qualified, rdf.iri(OWL_MAX_QUALIFIED_CARDINALITY), rdf.typed_literal("1", XSD_NON_NEGATIVE_INTEGER)})
	add(t, &target, {qualified, rdf.iri(OWL_ON_PROPERTY), qualified_property})
	add(t, &target, {qualified, rdf.iri(OWL_ON_CLASS), qualified_class})
	add(t, &target, {qualified_subject, rdf.iri(rdfs.RDF_TYPE), qualified})
	add(t, &target, {qualified_subject, qualified_property, qualified_left})
	add(t, &target, {qualified_subject, qualified_property, qualified_right})
	add(t, &target, {qualified_left, rdf.iri(rdfs.RDF_TYPE), qualified_class})
	add(t, &target, {qualified_right, rdf.iri(rdfs.RDF_TYPE), qualified_class})

	thing_qualified, thing_property, thing_subject := rdf.iri("urn:max-qualified-thing-one"), rdf.iri("urn:max-qualified-thing-property"), rdf.iri("urn:max-qualified-thing-subject")
	thing_left, thing_right := rdf.iri("urn:max-qualified-thing-left"), rdf.iri("urn:max-qualified-thing-right")
	literal_left, literal_right := rdf.literal("thing-left"), rdf.literal("thing-right")
	add(t, &target, {thing_qualified, rdf.iri(OWL_MAX_QUALIFIED_CARDINALITY), rdf.typed_literal("1", XSD_NON_NEGATIVE_INTEGER)})
	add(t, &target, {thing_qualified, rdf.iri(OWL_ON_PROPERTY), thing_property})
	add(t, &target, {thing_qualified, rdf.iri(OWL_ON_CLASS), rdf.iri(OWL_THING)})
	add(t, &target, {thing_subject, rdf.iri(rdfs.RDF_TYPE), thing_qualified})
	add(t, &target, {thing_subject, thing_property, thing_left})
	add(t, &target, {thing_subject, thing_property, thing_right})
	add(t, &target, {thing_subject, thing_property, literal_left})
	add(t, &target, {thing_subject, thing_property, literal_right})

	result := materialize(&profile, &target)
	testing.expect_value(t, result.error, rule.Error_Code.None)
	testing.expect(t, has(&target, {qualified_left, rdf.iri(OWL_SAME_AS), qualified_right}))
	testing.expect(t, has(&target, {thing_left, rdf.iri(OWL_SAME_AS), thing_right}))
	testing.expect(t, !has(&target, {literal_left, rdf.iri(OWL_SAME_AS), literal_right}))
}

@(test)
test_owlrl_vocabulary_batch_respects_store_term_limit :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target, {max_terms = 6}), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.Store_Error)
	testing.expect_value(t, store_error, store.Error_Code.Term_Limit)
	testing.expect_value(t, store.term_count(&target), 0)
}

@(test)
test_joint_owlrl_rdfs_limit_does_not_commit_partial_closure :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)

	add(t, &target, {rdf.iri("urn:A"), rdf.iri(OWL_EQUIVALENT_CLASS), rdf.iri("urn:B")})
	add(t, &target, {rdf.iri("urn:B"), rdf.iri(rdfs.RDFS_SUBCLASS), rdf.iri("urn:C")})
	add(t, &target, {rdf.iri("urn:x"), rdf.iri(rdfs.RDF_TYPE), rdf.iri("urn:A")})
	before := store.fact_count(&target)
	result := materialize(&profile, &target, {max_derivations = 1})
	testing.expect_value(t, result.error, rule.Error_Code.Max_Derivations)
	testing.expect_value(t, store.fact_count(&target), before)
}
