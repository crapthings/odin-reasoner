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

These thirty-one approved RDF-Based cases are represented by checked-in, minimal
rule-relevant N-Triples projections under [`testdata`](testdata/README.md).
Twenty-seven run through normal N-Triples import plus `materialize_all` or
`materialize_all_checked`; the four datatype cases use the explicit
`materialize_generalized_datatypes_checked` boundary because precise datatype
identity is intentionally an opt-in closure phase. They do not substitute for
executing each complete source ontology.

## Manifest status by scope

| Scope | Current result | Meaning |
| --- | --- | --- |
| Approved + RDF-Based archive cases | 31 selected gates pass; all 37 remaining cases have a recorded current-scope classification | Not a whole-manifest pass rate |
| Local OWL 2 RL/RDF table | 53 implemented directions plus seven labelled RDF-Based semantic supplement families mapped in the [rule ledger](conformance-ledger.md) | Authored rule and integration tests cover the documented bounded closure |
| Generalized RDF heads | Available only with `generalized_heads = true` | Strict RDF remains the default API behavior |
| `dt-type2`, `dt-eq`, `dt-diff`, `dt-not-type` | Exact only where `odin-rdf` has a complete value mapping | No inferred fact is emitted for `Unknown` pairs |
| Full OWL entailment, negative entailment, and profile-document validation | Not implemented as a conformance harness | The archive includes cases requiring unrestricted model-theoretic or syntax-translation behavior |
| Imports, OWL Functional Syntax, OWL/XML document processing | Not owned by `odin-reasoner` | Input boundary is application-owned RDF triples / parsers |

## Complete classification of the remaining archive cases

The following groups account for every remaining Approved + RDF-Based + RL
archive entry: 5 full-semantic positive entailments, 4 negative-entailment
tests, 11 ontology-document/mapping cases, 14 consistency or profile-validity
cases, and 3 description-logic inconsistency cases — 37 in total. These are explicit current-scope classifications, not
skipped passes.

| Archive group | Count | Classification | Why it is outside the current closure claim |
| --- | ---: | --- | --- |
| `DisjointClasses-001` / `-003`; `New-Feature-ObjectQCR-002`; `WebOnt-I5.26-010`; `WebOnt-I5.5-005` | 5 | Full-semantic positive entailment | The conclusions require complement-class construction or ontology-expression comprehension. None is an OWL RL/RDF forward-rule conclusion. |
| `New-Feature-Keys-004`; `New-Feature-ObjectPropertyChain-BJP-004`; `WebOnt-I4.6-004`; `WebOnt-I5.8-007` | 4 | Negative-entailment testing | The absence of a derived triple is not a proof of W3C negative entailment. These require a model witness or a dedicated negative-entailment harness. |
| `FS2RDF-different-individuals-2-ar` / `-3-ar`, `FS2RDF-no-builtin-prefixes-ar`, `FS2RDF-same-individual-2-ar`, `New-Feature-AnnotationAnnotations-001`, `New-Feature-AxiomAnnotations-001`, `WebOnt-AnnotationProperty-003` / `-004`, `WebOnt-backwardCompatibleWith-002`, `WebOnt-imports-011`, `WebOnt-miscellaneous-303` | 11 | Ontology document mapping | These test OWL Functional Syntax/RDF/XML parsing, imports, annotations, or ontology-document profile handling. The reasoner intentionally starts at asserted RDF triples. |
| `New-Feature-Keys-005`; `WebOnt-I5.26-001` / `-002` / `-005`; `WebOnt-disjointWith-003` through `-009`; `owl2-rl-anonymous-individual`; `owl2-rl-valid-oneof`; `owl2-rl-valid-rightside-allvaluesfrom` | 14 | Consistency or profile-validity only | A bounded forward closure can report supported contradictions, but it cannot prove arbitrary ontology consistency or OWL profile validity merely by finding no conflict. |
| `WebOnt-description-logic-101` / `-103` / `-104` | 3 | Full description-logic inconsistency | These depend on complement-class and nested class-expression semantics beyond the implemented false-rule set. |

## Next acceptance work

1. Keep the 31 executable gates green and only promote a newly added archive
   case after its complete source conclusion or contradiction is represented by
   a checked-in, rule-relevant fixture.
2. Treat the five classified boundary families above as separate capability
   projects: model witnesses for negative entailment, ontology-document
   processing, profile-validity analysis, full class-expression semantics, and
   description-logic inconsistency must not be introduced implicitly through a
   local rule patch.
3. No ordinary W3C RL/RDF rule-table direction remains unimplemented in this
   bounded profile. The next increment must explicitly choose one of the
   boundary capabilities above rather than presenting a semantic supplement as
   full OWL conformance.
