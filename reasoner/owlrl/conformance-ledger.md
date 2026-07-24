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

The test suite currently provides authored unit and integration fixtures. No
external OWL W3C test-suite manifest or fixture is pinned yet, so this document
does not claim a W3C fixture pass count. A future pinned fixture may be added
only when the fixture's complete expected conclusion is expressible by this
strict-RDF, bounded profile.

## Static entailment table

| W3C direction / local IDs | Local gate | Boundary checked |
| --- | --- | --- |
| `cax-eqc1`, `cax-eqc2` / 101–102 | `profile_test:test_equivalence_rules_compose_with_rdfs_core_at_one_fixpoint` | RDFS composition |
| `prp-eqp1`, `prp-eqp2` / 103–104 | `profile_test:test_equivalence_rules_compose_with_rdfs_core_at_one_fixpoint`, `test_object_property_rules_compose_at_one_fixpoint` | property closure |
| `prp-inv1`, `prp-inv2`, `prp-symp`, `prp-trp` / 105–108 | `profile_test:test_object_property_rules_compose_at_one_fixpoint`, `test_reversing_property_rules_skip_literal_subject_heads` | reverse literal heads are omitted under strict RDF |
| `scm-dom1`, `scm-dom2`, `scm-rng1`, `scm-rng2` / 109–112 | `profile_test:test_schema_domain_and_range_rules_drive_rdfs_instance_closure` | schema and instance closure |
| `cls-hv1`, `cls-hv2`, `cls-svf1`, `cls-svf2`, `cls-avf` / 113–117 | `profile_test:test_value_restriction_rules_handle_forward_reverse_and_thing_cases`, `test_all_values_from_skips_literal_subject_type_conclusion` | strict-RDF literal-head omission |
| `scm-eqc1`, reverse, `scm-eqc2`, `scm-eqp1`, reverse, `scm-eqp2` / 118–123 | `profile_test:test_schema_equivalence_rules_close_class_property_and_instance_views` | class/property schema closure |
| `scm-hv`, `scm-svf1`, `scm-svf2`, `scm-avf1`, `scm-avf2` / 124–128 | `profile_test:test_restriction_schema_subsumption_rules_preserve_each_direction` | both AVF directions are distinct |
| `eq-ref` subject/predicate/object, `eq-sym`, `eq-trans`, replacement subject/predicate/object / 129–136 | `profile_test:test_same_as_closure_replaces_subject_predicate_and_object`, `test_same_as_literal_boundary_preserves_object_replacement_only` | generalized-RDF literal subjects are omitted |
| `prp-fp`, `prp-ifp` / 137–138 | `profile_test:test_functional_properties_derive_equality_and_replacement`, `test_functional_property_skips_literal_subject_equality_head` | literal equality heads are omitted |
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

`rdf_list_test` independently covers owned list decoding, empty lists, malformed
nodes, cycles, item limits, and cleared partial output. `materialize_all_test`
also covers malformed-list and path-frontier rollback, plus complete-closure
provenance replacement. Focused dynamic entry points retain their smaller
origin-only contract; `materialize_all` is the gate for dynamic provenance.

## Consistency and atomicity gates

- `consistency_test:test_materialize_checked_reports_each_supported_false_rule`
  covers implemented false directions: `eq-diff1`, class/property disjointness,
  complements, all-disjoint classes/properties, negative assertions,
  all-different, `owl:Nothing`, irreflexivity, and asymmetry.
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

Not implemented: `prp-key` / `owl:hasKey`; cardinality restrictions; datatype
entailment and datatype false rules; RDF-list false rules; reflexive-property
entailment; schema self-axioms outside the documented 141–148 seed; generalized
RDF literal-subject equality; and every other W3C OWL 2 RL direction not listed
above. A term being reserved in the vocabulary is not evidence that its rule is
implemented.
