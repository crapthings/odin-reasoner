package owlrl

import "core:testing"
import rdf "odin-rdf:rdf"
import rdfs "../rdfs"
import store "../store"

@(test)
test_range_countermodel_proves_w3c_i5_8_007_nonentailment :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	if !load_ntriples_fixture(t, "reasoner/owlrl/testdata/w3c-i5-8-007.input.nt", &target) do return
	nonconclusion: store.Store
	testing.expect_value(t, store.init(&nonconclusion), store.Error_Code.None)
	defer store.destroy(&nonconclusion)
	if !load_ntriples_fixture(t, "reasoner/owlrl/testdata/w3c-i5-8-007.nonconclusion.nt", &nonconclusion) do return
	_, nonconclusion_fact, _, found := store.fact_at(&nonconclusion, 0)
	testing.expect(t, found)
	if !found do return
	nonconclusion_triple, triple_found := store.triple_for(&nonconclusion, store.Fact_ID(1))
	testing.expect(t, triple_found)
	if !triple_found do return
	short := rdf.iri("http://www.w3.org/2001/XMLSchema#short")
	_ = nonconclusion_fact
	result := verify_range_countermodel(&target, {
		property = nonconclusion_triple.subject,
		premise_range = short,
		nonconclusion_range = nonconclusion_triple.object,
		witness_value = rdf.typed_literal("-1", "http://www.w3.org/2001/XMLSchema#short"),
	})
	testing.expect_value(t, result.status, Negative_Entailment_Status.Countermodel)
}

@(test)
test_range_countermodel_rejects_an_unsupported_premise :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	property := rdf.iri("urn:p")
	short := rdf.iri("http://www.w3.org/2001/XMLSchema#short")
	unsigned_byte := rdf.iri("http://www.w3.org/2001/XMLSchema#unsignedByte")
	_, range_error := store.insert_triple(&target, {property, rdf.iri(rdfs.RDFS_RANGE_IRI), short})
	_, extra_error := store.insert_triple(&target, {rdf.iri("urn:other"), rdf.iri("urn:q"), rdf.iri("urn:value")})
	testing.expect_value(t, range_error, store.Error_Code.None)
	testing.expect_value(t, extra_error, store.Error_Code.None)
	result := verify_range_countermodel(&target, {property = property, premise_range = short, nonconclusion_range = unsigned_byte, witness_value = rdf.typed_literal("-1", "http://www.w3.org/2001/XMLSchema#short")})
	testing.expect_value(t, result.status, Negative_Entailment_Status.Unsupported)
}

@(test)
test_class_equivalence_countermodel_proves_w3c_i4_6_004_nonentailment :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	if !load_ntriples_fixture(t, "reasoner/owlrl/testdata/w3c-i4-6-004.input.nt", &target) do return
	left := rdf.iri("http://www.w3.org/2002/03owlt/I4.6/nonconclusions004#C1")
	right := rdf.iri("http://www.w3.org/2002/03owlt/I4.6/nonconclusions004#C2")
	result := verify_class_equivalence_countermodel(&target, {left = left, right = right})
	testing.expect_value(t, result.status, Negative_Entailment_Status.Countermodel)
}

@(test)
test_property_chain_countermodel_proves_w3c_bjp_004_nonentailment :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	if !load_ntriples_fixture(t, "reasoner/owlrl/testdata/w3c-object-property-chain-bjp-004.input.nt", &target) do return
	nonconclusion: store.Store
	testing.expect_value(t, store.init(&nonconclusion), store.Error_Code.None)
	defer store.destroy(&nonconclusion)
	if !load_ntriples_fixture(t, "reasoner/owlrl/testdata/w3c-object-property-chain-bjp-004.nonconclusion.nt", &nonconclusion) do return
	nonconclusion_triple, found := store.triple_for(&nonconclusion, store.Fact_ID(1))
	testing.expect(t, found)
	if !found do return
	result := verify_property_chain_countermodel(&target, {
		property = nonconclusion_triple.subject,
		second_property = rdf.iri("http://example.org/q"),
		left = rdf.iri("urn:model-left"),
		middle = rdf.iri("urn:model-middle"),
		right = rdf.iri("urn:model-right"),
	})
	testing.expect_value(t, result.status, Negative_Entailment_Status.Countermodel)
}

@(test)
test_has_key_countermodel_proves_w3c_keys_004_nonentailment :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	if !load_ntriples_fixture(t, "reasoner/owlrl/testdata/w3c-keys-004.input.nt", &target) do return
	nonconclusion: store.Store
	testing.expect_value(t, store.init(&nonconclusion), store.Error_Code.None)
	defer store.destroy(&nonconclusion)
	if !load_ntriples_fixture(t, "reasoner/owlrl/testdata/w3c-keys-004.nonconclusion.nt", &nonconclusion) do return
	nonconclusion_triple, found := store.triple_for(&nonconclusion, store.Fact_ID(1))
	testing.expect(t, found)
	if !found do return
	result := verify_has_key_countermodel(&target, {
		class = rdf.iri("http://example.org/GriffinFamilyMember"),
		property = rdf.iri("http://example.org/hasName"),
		keyed_left = nonconclusion_triple.subject,
		keyed_right = rdf.iri("http://example.org/Peter_Griffin"),
		outsider = nonconclusion_triple.object,
		key_value = rdf.literal("Peter"),
	})
	testing.expect_value(t, result.status, Negative_Entailment_Status.Countermodel)
}

@(test)
test_has_key_consistency_model_proves_w3c_keys_005_consistency :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	if !load_ntriples_fixture(t, "reasoner/owlrl/testdata/w3c-keys-005.input.nt", &target) do return
	result := verify_has_key_consistency_model(&target, {
		class = rdf.iri("http://example.org/GriffinFamilyMember"),
		property = rdf.iri("http://example.org/hasName"),
		individual = rdf.iri("http://example.org/Peter"),
		first_value = rdf.literal("Peter"),
		second_value = rdf.literal("Kichwa-Tembo"),
	})
	testing.expect_value(t, result.status, Consistency_Model_Status.Model)
}

@(test)
test_structure_sharing_models_prove_w3c_i5_26_consistency :: proc(t: ^testing.T) {
	fixtures := []struct { path: string, mode: int }{
		{"reasoner/owlrl/testdata/w3c-i5-26-001.input.nt", 1},
		{"reasoner/owlrl/testdata/w3c-i5-26-002.input.nt", 2},
		{"reasoner/owlrl/testdata/w3c-i5-26-005.input.nt", 5},
	}
	for fixture in fixtures {
		target: store.Store
		testing.expect_value(t, store.init(&target), store.Error_Code.None)
		if !load_ntriples_fixture(t, fixture.path, &target) { store.destroy(&target); continue }
		defer store.destroy(&target)
		if fixture.mode == 1 {
			result := verify_intersection_type_structure_sharing_model(&target, rdf.iri("http://example.org/B"), rdf.iri("http://example.org/C"))
			testing.expect_value(t, result.status, Consistency_Model_Status.Model)
		} else if fixture.mode == 2 {
			result := verify_equivalent_type_structure_sharing_model(&target, rdf.iri("http://example.org/B"), rdf.iri("http://example.org/A"))
			testing.expect_value(t, result.status, Consistency_Model_Status.Model)
		} else {
			result := verify_equivalent_disjoint_structure_sharing_model(&target, rdf.iri("http://example.org/B"), rdf.iri("http://example.org/C"), rdf.iri("http://example.org/D"))
			testing.expect_value(t, result.status, Consistency_Model_Status.Model)
		}
	}
}

@(test)
test_disjoint_class_edge_model_proves_w3c_disjoint_with_consistency :: proc(t: ^testing.T) {
	fixtures := []string{
		"reasoner/owlrl/testdata/w3c-disjoint-with-003.input.nt",
		"reasoner/owlrl/testdata/w3c-disjoint-with-004.input.nt",
		"reasoner/owlrl/testdata/w3c-disjoint-with-005.input.nt",
		"reasoner/owlrl/testdata/w3c-disjoint-with-006.input.nt",
		"reasoner/owlrl/testdata/w3c-disjoint-with-007.input.nt",
		"reasoner/owlrl/testdata/w3c-disjoint-with-008.input.nt",
		"reasoner/owlrl/testdata/w3c-disjoint-with-009.input.nt",
	}
	for path in fixtures {
		target: store.Store
		testing.expect_value(t, store.init(&target), store.Error_Code.None)
		if !load_ntriples_fixture(t, path, &target) { store.destroy(&target); continue }
		result := verify_disjoint_class_edges_consistency_model(&target)
		testing.expect_value(t, result.status, Consistency_Model_Status.Model)
		store.destroy(&target)
	}
}

@(test)
test_class_expression_proof_reports_w3c_description_logic_contradictions :: proc(t: ^testing.T) {
	fixtures := []string{
		"reasoner/owlrl/testdata/w3c-description-logic-101.input.nt",
		"reasoner/owlrl/testdata/w3c-description-logic-103.input.nt",
		"reasoner/owlrl/testdata/w3c-description-logic-104.input.nt",
	}
	for path in fixtures {
		target: store.Store
		testing.expect_value(t, store.init(&target), store.Error_Code.None)
		if !load_ntriples_fixture(t, path, &target) { store.destroy(&target); continue }
		result := verify_class_expression_contradiction(&target, rdf.iri("http://example.org/Unsatisfiable"))
		testing.expect_value(t, result.status, Inconsistency_Proof_Status.Contradiction)
		store.destroy(&target)
	}
}

@(test)
test_profile_shape_models_prove_w3c_rl_consistency_semantics :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	if load_ntriples_fixture(t, "reasoner/owlrl/testdata/w3c-rl-anonymous-individual.input.nt", &target) {
		result := verify_anonymous_individual_consistency_model(&target, rdf.iri("http://owl2.test/rules#I"))
		testing.expect_value(t, result.status, Consistency_Model_Status.Model)
	}
	store.destroy(&target)

	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	if load_ntriples_fixture(t, "reasoner/owlrl/testdata/w3c-rl-valid-oneof.input.nt", &target) {
		result := verify_one_of_subclass_consistency_model(&target, rdf.iri("http://owl2.test/rules#Cb"), rdf.iri("http://owl2.test/rules#X"), rdf.iri("http://owl2.test/rules#Y"))
		testing.expect_value(t, result.status, Consistency_Model_Status.Model)
	}
	store.destroy(&target)

	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	if load_ntriples_fixture(t, "reasoner/owlrl/testdata/w3c-rl-valid-rightside-allvaluesfrom.input.nt", &target) {
		result := verify_all_values_from_subclass_consistency_model(&target, rdf.iri("http://owl2.test/rules#C"), rdf.iri("http://owl2.test/rules#op"), rdf.iri("http://owl2.test/rules#C1"))
		testing.expect_value(t, result.status, Consistency_Model_Status.Model)
	}
	store.destroy(&target)
}
