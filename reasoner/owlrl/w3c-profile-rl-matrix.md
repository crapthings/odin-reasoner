# W3C OWL 2 Profile-RL compatibility matrix

## Purpose and source

This matrix separates executable evidence from scope that is merely allowed by
the OWL 2 RL profile. It prevents a green local rule suite from being presented
as a pass of the entire OWL 2 conformance corpus.

The baseline is W3C's static
[`profile-RL.rdf`](https://www.w3.org/2009/11/owl-test/profile-RL.rdf)
archive export. The source used for this assessment has SHA-256
`6415369555af022fedd0fe9a7d6b56eb274f89284e4109d7303540ec75c76988`.
It contains 91 entries: 70 marked approved, 89 applicable to RDF-Based
Semantics, and 68 in their intersection. The archive is a fixed historical
test source; it is not downloaded by the local gate.

The W3C conformance document itself notes that the test suite is incomplete:
passing its cases would not by itself prove conformance. Conversely, this
bounded reasoner deliberately does not claim a pass of the manifest while
many entries remain outside its rule-closure contract.

## Current executable selection

| Archive case | W3C rule / behavior | Gate | Status |
| --- | --- | --- | --- |
| `New-Feature-ObjectPropertyChain-001` | `prp-spo2` | `fixture_corpus_test:test_fixture_corpus_materializes_supported_rule_clusters` | pass |
| `New-Feature-ObjectPropertyChain-BJP-003` | `prp-spo2` | same | pass |
| `chain2trans1` | two-step self property chain → transitive property | same | pass |
| `New-Feature-Keys-003` | `prp-key` | same | pass |
| `New-Feature-Keys-006` | string `dt-diff`, `prp-fp`, `eq-diff1` contradiction | `fixture_corpus_test:test_fixture_corpus_reports_pinned_w3c_rl_rdf_functionality_datatype_conflict` | pass |
| `New-Feature-DisjointDataProperties-001` | `prp-pdw` contradiction | `fixture_corpus_test:test_fixture_corpus_reports_pinned_w3c_rl_rdf_conflicts` | pass |
| `New-Feature-DisjointDataProperties-002` | list-based property-disjoint individual difference | `fixture_corpus_test:test_fixture_corpus_materializes_supported_rule_clusters` | pass |
| `New-Feature-DisjointObjectProperties-001` | binary property-disjoint individual difference | same | pass |
| `New-Feature-DisjointObjectProperties-002` | list-based property-disjoint individual difference | same | pass |
| `owl2-rl-rules-fp-differentFrom` | functional-property inequality preservation | same | pass |
| `owl2-rl-rules-ifp-differentFrom` | inverse-functional-property inequality preservation | same | pass |
| `New-Feature-AsymmetricProperty-001` | `prp-asyp` contradiction | same | pass |
| `New-Feature-NegativeObjectPropertyAssertion-001` | `prp-npa1` contradiction | same | pass |
| `DisjointClasses-002` | `cax-dw` contradiction | same | pass |
| `New-Feature-IrreflexiveProperty-001` | `prp-irp` contradiction | same | pass |
| `DisjointClasses-001` / `-003` | binary/list class disjointness → complement-class witness | same | pass |
| `New-Feature-ObjectQCR-002` | max qualified cardinality plus inequality → complement-class witness | same | pass |
| `WebOnt-I5.26-010` | object property → min-cardinality restriction witness | same | pass |
| `WebOnt-I5.5-005` | class → singleton union-expression witness | same | pass |
| `WebOnt-I5.8-007` | finite range countermodel | `negative_entailment_test:test_range_countermodel_proves_w3c_i5_8_007_nonentailment` | pass |
| `WebOnt-I4.6-004` | finite class-equivalence countermodel | `negative_entailment_test:test_class_equivalence_countermodel_proves_w3c_i4_6_004_nonentailment` | pass |
| `New-Feature-ObjectPropertyChain-BJP-004` | finite property-chain countermodel | `negative_entailment_test:test_property_chain_countermodel_proves_w3c_bjp_004_nonentailment` | pass |
| `New-Feature-Keys-004` | finite localized-key countermodel | `negative_entailment_test:test_has_key_countermodel_proves_w3c_keys_004_nonentailment` | pass |
| `New-Feature-Keys-005` | finite localized-key consistency model | `negative_entailment_test:test_has_key_consistency_model_proves_w3c_keys_005_consistency` | pass |
| `WebOnt-I5.26-001` / `-002` / `-005` | finite structure-sharing consistency models | `negative_entailment_test:test_structure_sharing_models_prove_w3c_i5_26_consistency` | pass |
| `WebOnt-disjointWith-003` through `-009` | finite empty-class consistency model | `negative_entailment_test:test_disjoint_class_edge_model_proves_w3c_disjoint_with_consistency` | pass |
| `WebOnt-description-logic-101` / `-103` / `-104` | complement-class contradiction proof | `negative_entailment_test:test_class_expression_proof_reports_w3c_description_logic_contradictions` | pass |
| `owl2-rl-anonymous-individual`, `owl2-rl-valid-oneof`, `owl2-rl-valid-rightside-allvaluesfrom` | finite profile-shape consistency models | `negative_entailment_test:test_profile_shape_models_prove_w3c_rl_consistency_semantics` | pass |
| `FS2RDF-different-individuals-2-ar` / `-3-ar`, `FS2RDF-no-builtin-prefixes-ar`, `FS2RDF-same-individual-2-ar` | bounded Functional Syntax → RDF mapping | `functional_test:test_maps_selected_w3c_functional_syntax_cases` | pass |
| `New-Feature-AnnotationAnnotations-001`, `New-Feature-AxiomAnnotations-001` | RDF/XML annotation/reification mapping | `triple_sink_test:test_rdfxml_adapter_preserves_w3c_annotation_and_axiom_reification_shapes` | pass |
| `WebOnt-AnnotationProperty-003` / `-004`, `WebOnt-backwardCompatibleWith-002`, `WebOnt-miscellaneous-303` | RDF/XML metadata mapping | `triple_sink_test:test_rdfxml_adapter_preserves_w3c_annotation_property_and_metadata_shapes` | pass |
| `WebOnt-imports-011` | RDF/XML recursive import closure | `import_closure_test:test_rdfxml_import_closure_proves_w3c_imports_011_entailment` | pass |
| `WebOnt-equivalentProperty-002` / `-003` | `scm-eqp1` / `scm-eqp2` | `fixture_corpus_test:test_fixture_corpus_materializes_supported_rule_clusters` | pass |
| `WebOnt-equivalentClass-002` / `-003` | `scm-eqc1` / `scm-eqc2` | same | pass |
| `WebOnt-sameAs-001` | `eq-rep-s` | same | pass |
| `Plus and Minus Zero are Distinct` | `dt-diff`, `prp-fp`, `eq-diff1` contradiction | `fixture_corpus_test:test_fixture_corpus_reports_pinned_w3c_rl_rdf_signed_zero_datatype_conflict` | pass |
| `New-Feature-NegativeDataPropertyAssertion-001` | `prp-npa2` contradiction | `fixture_corpus_test:test_fixture_corpus_reports_pinned_w3c_rl_rdf_conflicts` | pass |
| `functionality-clash` | `dt-diff`, `prp-fp`, `eq-diff1` contradiction | `fixture_corpus_test:test_fixture_corpus_reports_pinned_w3c_rl_rdf_functionality_datatype_conflict` | pass |
| `string-integer-clash` | `scm-rng`, `dt-not-type` contradiction | same | pass |
| `WebOnt-Nothing-001` | `cls-nothing2` contradiction | `fixture_corpus_test:test_fixture_corpus_reports_pinned_w3c_rl_rdf_conflicts` | pass |
| `WebOnt-differentFrom-001` | RDF-Based `owl:differentFrom` symmetry | `fixture_corpus_test:test_fixture_corpus_materializes_supported_rule_clusters` | pass |
| `WebOnt-I5.8-011` | `dt-type1` zero-premise datatype axioms | same | pass |
| `WebOnt-I5.8-006` | numeric datatype hierarchy + `scm-rng1` | same | pass |
| `WebOnt-I5.8-008` | `xsd:short` ∩ `xsd:unsignedInt` range → `xsd:unsignedShort` | same | pass |
| `WebOnt-I5.8-009` | `xsd:nonNegativeInteger` ∩ `xsd:nonPositiveInteger` range → `xsd:short` | same | pass |
| `New-Feature-ReflexiveProperty-001` | explicit named-individual reflexivity | same | pass |

Fifty-seven approved RDF-Based cases are represented by checked-in, minimal
rule-relevant N-Triples projections under [`testdata`](testdata/README.md), four
Functional Syntax mapping cases execute their original bounded source strings
through `reasoner/functional`, six annotation/metadata cases execute their
RDF/XML documents through the default-graph import adapter, and one case uses a
local callback resolver to exercise a two-document RDF/XML import closure.
Thirty-two run through normal N-Triples import plus `materialize_all` or
`materialize_all_checked`; the four datatype cases use the explicit
`materialize_generalized_datatypes_checked` boundary because precise datatype
identity is intentionally an opt-in closure phase. They do not substitute for
executing each complete source ontology.

## Manifest status by scope

| Scope | Current result | Meaning |
| --- | --- | --- |
| Approved + RDF-Based archive cases | All 68 selected gates pass | Not a whole-manifest pass rate |
| Local OWL 2 RL/RDF table | 53 implemented directions plus ten labelled RDF-Based semantic supplement families mapped in the [rule ledger](conformance-ledger.md) | Authored rule and integration tests cover the documented bounded closure |
| Generalized RDF heads | Available only with `generalized_heads = true` | Strict RDF remains the default API behavior |
| `dt-type2`, `dt-eq`, `dt-diff`, `dt-not-type` | Exact only where `odin-rdf` has a complete value mapping | No inferred fact is emitted for `Unknown` pairs |
| Full OWL entailment, negative entailment, and profile-document validation | Not implemented as a conformance harness | The archive includes cases requiring unrestricted model-theoretic or syntax-translation behavior |
| Imports, OWL Functional Syntax, OWL/XML document processing | Bounded RDF/XML import closure and selected Functional Syntax mappings | Network transport, most syntax, profile validation, and complete document semantics remain application-owned |

## Archive selection completeness

Every one of the 68 Approved + RDF-Based + RL entries in this static archive
now has an executable local gate. This records evidence for the explicitly
named consequence, contradiction, mapping, or finite-model certificate of each
case. It does not assert a pass of the complete W3C manifest, of full OWL
semantics, or of any network document-fetching behavior.

## Next acceptance work

1. Keep all 68 executable gates green. Extend this archive selection only with
   checked-in source evidence and a clearly stated semantic certificate.
2. Treat broader document support as a separate capability project: resolver
   policy and external-cache behavior, complete Functional Syntax and OWL/XML
   processing, profile-validity analysis, and unrestricted class expression
   semantics must not be introduced implicitly through a local rule patch.
3. No ordinary W3C RL/RDF rule-table direction remains unimplemented in this
   bounded profile. The next increment must explicitly choose one of the
   boundary capabilities above rather than presenting a semantic supplement as
   full OWL conformance.
