# OWL 2 RL seed conformance ledger

## Claim boundary

This is an implementation ledger for the repository's bounded OWL 2 RL seed;
it is **not** a claim of complete OWL 2 RL conformance. Rule names are mapped
to the [W3C OWL 2 RL/RDF rule table](https://www.w3.org/TR/owl2-profiles/#Reasoning_in_OWL_2_RL_and_RDF_Graphs_Using_Rules), which is the normative
source for the named directions.

The local gate is:

```sh
odin test reasoner/owlrl -collection:odin-rdf=../odin-rdf
```

Its scenario-level [fixture corpus](testdata/README.md) is executed by
`fixture_corpus_test.odin`. The corpus complements the focused rule tests with
five multi-cluster successful closures, one list-derived checked conflict, and
two transactional materialization failures. Its expected N-Triples are required
conclusions rather than a claim to enumerate every profile closure fact.

The test suite provides authored unit and integration fixtures plus thirty-four
external W3C semantic vectors below. The thirty-one OWL 2 vectors are normalized
from a fixed W3C archive export; the three legacy OWL vectors are retained as
independent regression evidence. This is still not a complete OWL 2 suite pass
claim: the W3C Profile-RL manifest also contains conclusions that require
unrestricted OWL semantic reasoning beyond the forward OWL 2 RL/RDF rule
closure. A future fixture may be added only when its required conclusion or
contradiction is expressible by this strict-RDF, bounded profile.

## Pinned external W3C OWL semantic vectors

`conformance_test.odin:test_pinned_w3c_owl_property_entailment_vectors`
embeds only the statement records of three approved W3C OWL positive-entailment
inputs, normalized from their RDF/XML serialization to N-Triples at this
application-owned triple boundary. Each assertion checks the entire conclusion
document of its selected vector:

- [`SymmetricProperty/Manifest001`](https://www.w3.org/2002/03owlt/SymmetricProperty/Manifest001),
  whose [premise](https://www.w3.org/2002/03owlt/SymmetricProperty/premises001)
  and [conclusion](https://www.w3.org/2002/03owlt/SymmetricProperty/conclusions001)
  contain one reversed property triple.
- [`TransitiveProperty/Manifest001`](https://www.w3.org/2002/03owlt/TransitiveProperty/Manifest001),
  whose [premise](https://www.w3.org/2002/03owlt/TransitiveProperty/premises001)
  and [conclusion](https://www.w3.org/2002/03owlt/TransitiveProperty/conclusions001)
  contain one length-two transitive conclusion.
- [`FunctionalProperty/Manifest002`](https://www.w3.org/2002/03owlt/FunctionalProperty/Manifest002),
  whose [premise](https://www.w3.org/2002/03owlt/FunctionalProperty/premises002)
  and [conclusion](https://www.w3.org/2002/03owlt/FunctionalProperty/conclusions002)
  require functional equality followed by subject replacement.

These are legacy W3C OWL Test Cases, not the later OWL 2 test repository. They
provide independent regression evidence for the three listed property
directions only; they do not claim OWL 1, OWL 2, or full OWL 2 RL conformance.

`fixture_corpus_test.odin:test_fixture_corpus_materializes_supported_rule_clusters`
and `test_fixture_corpus_reports_pinned_w3c_rl_rdf_conflicts` additionally
run thirty-one approved RDF-Based OWL 2 RL test cases from the W3C static archive:

- [`New-Feature-ObjectPropertyChain-001`](https://www.w3.org/2009/11/owl-test/profile-RL.rdf),
  which derives the declared `hasAunt` property-chain consequence (`prp-spo2`).
- [`New-Feature-ObjectPropertyChain-BJP-003`](https://www.w3.org/2009/11/owl-test/profile-RL.rdf),
  which derives `a p c` from the two-step `p` then `q` chain declared for
  `p` (`prp-spo2`).
- [`chain2trans1`](https://www.w3.org/2009/11/owl-test/profile-RL.rdf),
  which derives that `p` is an `owl:TransitiveProperty` from its two-step
  self-chain declaration. This exact semantic consequence is tracked as a
  supplement rather than a W3C RL/RDF rule-table direction.
- [`New-Feature-Keys-003`](https://www.w3.org/2009/11/owl-test/profile-RL.rdf),
  which merges the two typed `GriffinFamilyMember` instances (`prp-key`).
- [`New-Feature-Keys-006`](https://www.w3.org/2009/11/owl-test/profile-RL.rdf),
  which reports a functional data-property contradiction for two distinct
  `xsd:string` values (`dt-diff`, `prp-fp`, `eq-diff1`); its key declaration is
  retained in the normalized fixture to preserve the source scenario.
- [`New-Feature-DisjointDataProperties-001`](https://www.w3.org/2009/11/owl-test/profile-RL.rdf),
  which reports the same subject/object pair under disjoint properties
  (`prp-pdw`).
- [`New-Feature-DisjointDataProperties-002`](https://www.w3.org/2009/11/owl-test/profile-RL.rdf)
  and [`New-Feature-DisjointObjectProperties-001`](https://www.w3.org/2009/11/owl-test/profile-RL.rdf)
  / `-002`, which infer pairwise different individuals from binary and
  `owl:AllDisjointProperties` encodings. This is an explicitly bounded
  RDF-Based semantic supplement, not a W3C RL/RDF rule-table direction.
- [`New-Feature-AsymmetricProperty-001`](https://www.w3.org/2009/11/owl-test/profile-RL.rdf)
  and [`New-Feature-IrreflexiveProperty-001`](https://www.w3.org/2009/11/owl-test/profile-RL.rdf),
  which report `prp-asyp` and `prp-irp` contradictions respectively.
- [`New-Feature-NegativeObjectPropertyAssertion-001`](https://www.w3.org/2009/11/owl-test/profile-RL.rdf),
  which reports a `prp-npa1` contradiction.
- [`DisjointClasses-002`](https://www.w3.org/2009/11/owl-test/profile-RL.rdf),
  which reports the `cax-dw` contradiction.
- [`WebOnt-equivalentProperty-002`](https://www.w3.org/2009/11/owl-test/profile-RL.rdf)
  and `-003`, which exercise `scm-eqp1` and `scm-eqp2`.
- [`WebOnt-equivalentClass-002`](https://www.w3.org/2009/11/owl-test/profile-RL.rdf)
  and `-003`, which exercise `scm-eqc1` and `scm-eqc2`.
- [`WebOnt-sameAs-001`](https://www.w3.org/2009/11/owl-test/profile-RL.rdf),
  which exercises sameAs subject replacement (`eq-rep-s`).
- `test_fixture_corpus_reports_pinned_w3c_rl_rdf_signed_zero_datatype_conflict` additionally
  runs the archive's `Plus and Minus Zero are Distinct` case through the
  explicit generalized-datatype closure. Its normalized projection proves that
  `+0.0` and `-0.0` are distinct OWL data values (`dt-diff`), so a functional
  property merge produces the required `eq-diff1` contradiction.
- [`New-Feature-NegativeDataPropertyAssertion-001`](https://www.w3.org/2009/11/owl-test/profile-RL.rdf)
  exercises the `prp-npa2` data-value branch of negative property assertions.
- `functionality-clash` verifies that two distinct `xsd:integer` values on a
  functional data property lead through `dt-diff`, `prp-fp`, and `eq-diff1` to
  a contradiction.
- `string-integer-clash` verifies that `scm-rng` emits the generalized
  literal-type fact and `dt-not-type` reports the incompatible `xsd:string`
  value asserted in an `xsd:integer` range.
- [`WebOnt-Nothing-001`](https://www.w3.org/2009/11/owl-test/profile-RL.rdf)
  verifies the direct `cls-nothing2` contradiction for an `owl:Nothing`
  instance.
- [`WebOnt-differentFrom-001`](https://www.w3.org/2009/11/owl-test/profile-RL.rdf)
  verifies the RDF-Based semantic consequence that `owl:differentFrom` is
  symmetric. This is tracked separately from the W3C RL/RDF rule table's
  `eq-diff` contradiction directions.
- [`WebOnt-I5.8-011`](https://www.w3.org/2009/11/owl-test/profile-RL.rdf)
  verifies `dt-type1` from an empty input graph: the archive conclusion for
  `xsd:integer` and `xsd:string` is covered by the checked-in projection.
- [`WebOnt-I5.8-006`](https://www.w3.org/2009/11/owl-test/profile-RL.rdf)
  verifies the exact `xsd:byte` → `xsd:short` numeric datatype hierarchy edge
  composed with `scm-rng1`.
- [`WebOnt-I5.8-008`](https://www.w3.org/2009/11/owl-test/profile-RL.rdf)
  verifies that the nonempty intersection of `xsd:short` and `xsd:unsignedInt`
  ranges entails the named `xsd:unsignedShort` range.
- [`WebOnt-I5.8-009`](https://www.w3.org/2009/11/owl-test/profile-RL.rdf)
  verifies that the singleton intersection of `xsd:nonNegativeInteger` and
  `xsd:nonPositiveInteger` ranges is contained in `xsd:short`.
- [`New-Feature-ReflexiveProperty-001`](https://www.w3.org/2009/11/owl-test/profile-RL.rdf)
  verifies a `knows` self-edge for an explicitly declared `owl:NamedIndividual`
  and `owl:ReflexiveProperty`. It is a deliberately bounded RDF-Based
  supplement, rather than a claim that the engine enumerates every resource in
  the graph as a reflexive witness.
- [`owl2-rl-rules-fp-differentFrom`](https://www.w3.org/2009/11/owl-test/profile-RL.rdf)
  and `-ifp-differentFrom` verify finite inequality preservation through
  functional and inverse-functional equality constraints. They are semantic
  supplements, not a claim that arbitrary contrapositive OWL reasoning is available.

The input source is the archive's fixed
[`profile-RL.rdf`](https://www.w3.org/2009/11/owl-test/profile-RL.rdf),
retrieved with SHA-256
`6415369555af022fedd0fe9a7d6b56eb274f89284e4109d7303540ec75c76988`.
Minimal rule-relevant N-Triples projections are checked into `testdata/` so
the gate stays offline and does not depend on a live W3C endpoint. They verify
the named OWL 2 RL/RDF rule consequence or explicitly labelled semantic
supplement, not the complete source ontology.

## Static entailment table

| W3C direction / local IDs | Local gate | Boundary checked |
| --- | --- | --- |
| `cax-eqc1`, `cax-eqc2` / 101–102 | `profile_test:test_equivalence_rules_compose_with_rdfs_core_at_one_fixpoint` | RDFS composition |
| `prp-ap` / 158 | `profile_test:test_builtin_annotation_property_axioms_have_zero_support`, `materialize_all_test:test_materialize_all_retains_zero_premise_annotation_axiom_provenance` | all nine OWL 2 built-in annotation properties and zero-premise provenance in both focused and complete closure |
| `dt-type1` / 159 | `profile_test:test_owl_rl_datatype_axioms_have_zero_support`, `materialize_all_test:test_materialize_all_retains_zero_premise_datatype_axiom_provenance` | all thirty-two W3C OWL 2 RL datatype resources and zero-premise provenance in both focused and complete closure |
| `cls-thing`, `cls-nothing1` / 163–164 | `profile_test:test_owl_rl_builtin_class_axioms_have_zero_support`, `materialize_all_test:test_materialize_all_retains_zero_premise_builtin_class_axiom_provenance` | both W3C built-in class axioms and zero-premise provenance in focused and complete closure |
| generalized `dt-type2`, `dt-eq`, `dt-diff` / 160–162 | `datatype_test:test_generalized_datatype_materialization_derives_exact_type_equality_and_difference`, `test_generalized_datatype_materialization_limit_is_transactional` | generalized RDF only; emits only exact `odin-rdf` Yes/Same/Different results and therefore is deliberately incomplete pending every datatype pair |
| signed floating data-value identity | `fixture_corpus_test:test_fixture_corpus_reports_pinned_w3c_rl_rdf_signed_zero_datatype_conflict` | `+0` and `-0` are distinct OWL data values even though XML Schema equality considers them equal |
| generalized dynamic list closure | `materialize_all_test:test_materialize_all_generalized_heads_reaches_every_dynamic_list_phase` | explicit `generalized_heads` opt-in covers literal-subject `cls-oo`, `prp-key`, and property-chain results across static and dynamic rounds; strict RDF remains the default |
| generalized `dt-not-type` | `datatype_test:test_generalized_datatype_checked_reports_dt_not_type` | generalized literal type assertions only; reports exact `odin-rdf` No results as contradictions |
| `prp-eqp1`, `prp-eqp2` / 103–104 | `profile_test:test_equivalence_rules_compose_with_rdfs_core_at_one_fixpoint`, `test_object_property_rules_compose_at_one_fixpoint` | property closure |
| `prp-inv1`, `prp-inv2`, `prp-symp`, `prp-trp` / 105–108 | `profile_test:test_object_property_rules_compose_at_one_fixpoint`, `test_reversing_property_rules_skip_literal_subject_heads` | reverse literal heads are omitted under strict RDF |
| `scm-dom1`, `scm-dom2`, `scm-rng1`, `scm-rng2` / 109–112 | `profile_test:test_schema_domain_and_range_rules_drive_rdfs_instance_closure` | schema and instance closure |
| `cls-hv1`, `cls-hv2`, `cls-svf1`, `cls-svf2`, `cls-avf` / 113–117 | `profile_test:test_value_restriction_rules_handle_forward_reverse_and_thing_cases`, `test_all_values_from_skips_literal_subject_type_conclusion` | strict-RDF literal-head omission |
| `scm-eqc1`, reverse, `scm-eqc2`, `scm-eqp1`, reverse, `scm-eqp2` / 118–123 | `profile_test:test_schema_equivalence_rules_close_class_property_and_instance_views` | class/property schema closure |
| `scm-hv`, `scm-svf1`, `scm-svf2`, `scm-avf1`, `scm-avf2` / 124–128 | `profile_test:test_restriction_schema_subsumption_rules_preserve_each_direction` | both AVF directions are distinct |
| dynamic `scm-int`, `scm-uni` / 165–166 | `intersection_test:test_intersection_list_rules_reach_joint_rdfs_fixpoint`, `union_test:test_union_list_rule_reaches_joint_rdfs_fixpoint`, `materialize_all_test:test_materialize_all_reaches_one_fixpoint_across_every_supported_list_phase` | list-derived subclass closure and first-support provenance |
| `eq-ref` subject/predicate/object, `eq-sym`, `eq-trans`, replacement subject/predicate/object / 129–136 | `profile_test:test_same_as_closure_replaces_subject_predicate_and_object`, `test_same_as_literal_boundary_preserves_object_replacement_only` | generalized-RDF literal subjects are omitted |
| RDF-Based `owl:differentFrom` symmetry | `profile_test:test_rdf_based_different_from_is_symmetric`, `fixture_corpus_test:test_fixture_corpus_materializes_supported_rule_clusters` | semantic supplement; intentionally not counted as a W3C RL/RDF table direction |
| RDF-Based numeric datatype hierarchy | `profile_test:test_rdf_based_numeric_datatype_hierarchy_reaches_transitive_supertypes`, `fixture_corpus_test:test_fixture_corpus_materializes_supported_rule_clusters` | thirteen exact immediate XML Schema numeric-derived-type edges; intentionally not counted as W3C RL/RDF table directions |
| RDF-Based numeric range intersection | `numeric_range_intersection_test:test_numeric_range_intersection_derives_exact_named_integer_ranges`, `fixture_corpus_test:test_fixture_corpus_materializes_supported_rule_clusters` | only nonempty pairwise intersections of the exact modeled integer datatype intervals; intentionally not counted as a W3C RL/RDF table direction |
| RDF-Based property-disjoint difference | `disjoint_property_difference_test:test_disjoint_property_difference_derives_binary_and_list_based_w3c_shapes`, `fixture_corpus_test:test_fixture_corpus_materializes_supported_rule_clusters` | binary `owl:propertyDisjointWith` and every pair in a valid `owl:AllDisjointProperties` list; infers only a difference forced by one shared endpoint, and is intentionally not counted as a W3C RL/RDF table direction |
| RDF-Based functional-property difference | `functional_property_difference_test:test_functional_property_difference_preserves_explicit_inequality`, `fixture_corpus_test:test_fixture_corpus_materializes_supported_rule_clusters` | preserves an asserted `owl:differentFrom` through two functional or inverse-functional property assertions; intentionally not counted as a W3C RL/RDF table direction |
| RDF-Based named-individual reflexivity | `profile_test:test_rdf_based_reflexive_property_closes_explicit_named_individuals`, `fixture_corpus_test:test_fixture_corpus_materializes_supported_rule_clusters` | `owl:NamedIndividual` subset only; intentionally not counted as a W3C RL/RDF table direction or a full-domain reflexivity claim |
| RDF-Based self-chain transitivity | `fixture_corpus_test:test_fixture_corpus_materializes_supported_rule_clusters` | exact two-item `P, P` chain only; intentionally not counted as a W3C RL/RDF rule-table direction |
| `prp-fp`, `prp-ifp` / 137–138 | `profile_test:test_functional_properties_derive_equality_and_replacement`, `test_functional_property_skips_literal_subject_equality_head` | literal equality heads are omitted |
| `cls-maxc2` / 154 | `profile_test:test_max_cardinality_one_derives_representable_equality_only` | literal equality heads are omitted under strict RDF |
| `cls-maxqc3`, `cls-maxqc4` / 155–156 | `profile_test:test_max_qualified_cardinality_one_derives_representable_equality_only` | literal equality heads are omitted under strict RDF |
| `cls-hasSelf1`, `cls-hasSelf2` / 139–140 | `profile_test:test_has_self_rules_require_typed_boolean_true_and_compose_with_rdfs` | only typed `"true"^^xsd:boolean` enables the rule |
| class schema `scm-cls` directions / 141–144 | `profile_test:test_owl_class_schema_rules_emit_all_four_consequences` | explicit four consequences |
| object-property schema `scm-op` directions / 145–146 | `profile_test:test_object_property_schema_rules_emit_both_consequences` | explicit two consequences |
| datatype-property schema `scm-dp` directions / 147–148 | `profile_test:test_datatype_property_schema_rules_emit_both_consequences` | explicit two consequences |

## Dynamic RDF-list table

| W3C direction / local ID | Local gate | Boundary checked |
| --- | --- | --- |
| `cls-oo` / 149 | `one_of_test:test_one_of_list_rule_reaches_joint_rdfs_fixpoint`; `materialize_all_test:test_materialize_all_reaches_one_fixpoint_across_every_supported_list_phase` | bounded well-formed lists and first-support evidence |
| `cls-int1` / 150 | `intersection_test:test_intersection_list_rules_reach_joint_rdfs_fixpoint`; `materialize_all_test:test_materialize_all_reaches_one_fixpoint_across_every_supported_list_phase` | all member types required |
| `cls-int2` / 151 | `intersection_test:test_intersection_list_rules_reach_joint_rdfs_fixpoint`; `materialize_all_test:test_materialize_all_reaches_one_fixpoint_across_every_supported_list_phase` | stable reverse-direction provenance |
| `cls-uni` / 152 | `union_test:test_union_list_rule_reaches_joint_rdfs_fixpoint`; `materialize_all_test:test_materialize_all_reaches_one_fixpoint_across_every_supported_list_phase` | empty list has no finite conclusion |
| `prp-spo2` / 153 | `property_chain_test:test_property_chain_materializes_exact_paths_and_reaches_rdfs_fixpoint`; `materialize_all_test:test_materialize_all_reaches_one_fixpoint_across_every_supported_list_phase` | two-or-more IRI properties and first path support |
| `prp-key` / 157 | `has_key_test:test_materialize_all_has_key_matches_every_list_property`, `test_materialize_all_has_key_empty_list_matches_class_instances`, `test_materialize_all_has_key_malformed_list_is_transactional` | arbitrary well-formed (including empty) key lists, first-support evidence, and malformed-list rollback |

`rdf_list_test` independently covers owned list decoding, empty lists, malformed
nodes, cycles, item limits, and cleared partial output. `materialize_all_test`
also covers malformed-list and path-frontier rollback, plus complete-closure
provenance replacement. Focused dynamic entry points retain their smaller
origin-only contract; `materialize_all` is the gate for dynamic provenance.

## Consistency and atomicity gates

- `consistency_test:test_materialize_checked_reports_each_supported_false_rule`
  covers implemented false directions: `eq-diff1`, `eq-diff2`
  (`owl:members`) and `eq-diff3` (`owl:distinctMembers`) for
  `owl:AllDifferent`; `cax-dw`, `cax-adc`, `cls-com`, `prp-pdw`, and
  `prp-adp`; `prp-npa1` and `prp-npa2`; `cls-nothing2`; `prp-irp`; and
  `prp-asyp`; and `cls-maxc1` for canonical
  `"0"^^xsd:nonNegativeInteger` cardinalities; and `cls-maxqc1` / `cls-maxqc2`
  for canonical zero qualified cardinalities.
- `materialize_all_checked_test:test_materialize_all_checked_reports_dynamic_list_contradictions_after_commit`
  proves a list-derived class fact participates in consistency analysis.
- `materialize_all_checked_test:test_materialize_all_checked_keeps_dynamic_failure_transactional_and_clears_report`
  proves a malformed dynamic list exposes neither partial closure nor report.
- `materialize_all_checked_test:test_materialize_all_checked_keeps_successful_closure_on_report_limit`
  proves a report limit clears evidence without retracting a committed closure.
- `profile_test:test_same_as_resource_limit_keeps_source_unchanged`,
  `test_joint_owlrl_rdfs_limit_does_not_commit_partial_closure`, the focused
  list limit tests, and `materialize_all_test` cover atomic configured-limit
  failures.

## Deliberately unmapped OWL 2 RL directions

Not implemented: datatype value-space/equality pairs intentionally represented as `Unknown`; schema self-axioms outside the documented
141–148 seed; generalized
RDF literal-subject equality; and every other W3C OWL 2 RL direction not listed
above. A term being reserved in the vocabulary is not evidence that its rule is
implemented.

The W3C OWL 2 RL/RDF rule table has no reflexive-property direction. The
explicit `owl:NamedIndividual` subset above is therefore tracked as an
RDF-Based semantic supplement, not as a complete model-theoretic
`owl:ReflexiveProperty` implementation.
