# OWL RL fixture corpus

These N-Triples files are a scenario-level regression corpus for the bounded
OWL RL profile. Each `*.input.nt` is application-owned asserted data; its
paired `*.expected.nt` is the complete set of conclusions required by that
fixture, not a claim that it enumerates every closure fact. Expected files use
only IRIs and literals so they remain comparable across parser-scoped blank
nodes.

`fixture_corpus_test.odin` is the executable manifest. It loads every file
through the ordinary parser/import boundary and uses `materialize_all` or
`materialize_all_checked` according to the case.

| Fixture | Gate | Main rule coverage |
| --- | --- | --- |
| `01-schema-identity` | successful closure | equivalence, schema/domain, equality replacement, inverse-functional property (101–104, 109–123, 129–138) |
| `02-property-relations` | successful closure | inverse, symmetric, transitive, equivalent properties (105–108) |
| `03-restrictions-self` | successful closure | value restrictions, restriction schema, typed `hasSelf` (113–117, 124–128, 139–140) |
| `04-lists-chain` | successful closure | all four supported RDF-list families (149–153) composed with RDFS |
| `05-declarations` | successful closure | OWL class, object-property, datatype-property schema consequences (141–148) |
| `06-list-conflict` | checked closure | list-derived class membership followed by a disjoint-class report |
| `07-malformed-list` | failed closure | malformed list reports `Missing_Rest` and commits no partial closure |
| `08-path-limit` | failed closure | property-chain frontier limit commits no partial closure |
| `w3c-object-property-chain-001` | successful closure | W3C `New-Feature-ObjectPropertyChain-001`, `prp-spo2` |
| `w3c-object-property-chain-bjp-003` | successful closure | W3C `New-Feature-ObjectPropertyChain-BJP-003`, `prp-spo2` |
| `w3c-chain2trans1` | successful closure | W3C `chain2trans1`, two-step self property-chain transitivity |
| `w3c-keys-003` | successful closure | W3C `New-Feature-Keys-003`, `prp-key` |
| `w3c-keys-006` | generalized datatype checked closure | W3C `New-Feature-Keys-006`, string `dt-diff`, `prp-fp`, `eq-diff1` |
| `w3c-equivalent-property-002` | successful closure | W3C `WebOnt-equivalentProperty-002`, `scm-eqp1` |
| `w3c-equivalent-property-003` | successful closure | W3C `WebOnt-equivalentProperty-003`, `scm-eqp2` |
| `w3c-equivalent-class-002` | successful closure | W3C `WebOnt-equivalentClass-002`, `scm-eqc1` |
| `w3c-equivalent-class-003` | successful closure | W3C `WebOnt-equivalentClass-003`, `scm-eqc2` |
| `w3c-same-as-001` | successful closure | W3C `WebOnt-sameAs-001`, `eq-rep-s` |
| `w3c-disjoint-data-properties-001` | checked closure | W3C `New-Feature-DisjointDataProperties-001`, `prp-pdw` |
| `w3c-asymmetric-property-001` | checked closure | W3C `New-Feature-AsymmetricProperty-001`, `prp-asyp` |
| `w3c-negative-object-property-assertion-001` | checked closure | W3C `New-Feature-NegativeObjectPropertyAssertion-001`, `prp-npa1` |
| `w3c-disjoint-classes-002` | checked closure | W3C `DisjointClasses-002`, `cax-dw` |
| `w3c-irreflexive-property-001` | checked closure | W3C `New-Feature-IrreflexiveProperty-001`, `prp-irp` |
| `w3c-plus-minus-zero` | generalized datatype checked closure | W3C `Plus and Minus Zero are Distinct`, `dt-diff`, `prp-fp`, `eq-diff1` |
| `w3c-negative-data-property-assertion-001` | checked closure | W3C `New-Feature-NegativeDataPropertyAssertion-001`, `prp-npa2` |
| `w3c-functionality-clash` | generalized datatype checked closure | W3C `functionality-clash`, `dt-diff`, `prp-fp`, `eq-diff1` |
| `w3c-string-integer-clash` | generalized datatype checked closure | W3C `string-integer-clash`, `scm-rng`, `dt-not-type` |
| `w3c-nothing-001` | checked closure | W3C `WebOnt-Nothing-001`, `cls-nothing2` |
| `w3c-different-from-001` | successful closure | W3C `WebOnt-differentFrom-001`, RDF-Based `owl:differentFrom` symmetry |
| `w3c-i5-8-011` | successful closure | W3C `WebOnt-I5.8-011`, `dt-type1` zero-premise datatype axioms |
| `w3c-i5-8-006` | successful closure | W3C `WebOnt-I5.8-006`, numeric datatype hierarchy plus `scm-rng1` |
| `w3c-i5-8-008` | successful closure | W3C `WebOnt-I5.8-008`, `xsd:short` ∩ `xsd:unsignedInt` range entails `xsd:unsignedShort` |
| `w3c-i5-8-009` | successful closure | W3C `WebOnt-I5.8-009`, `xsd:nonNegativeInteger` ∩ `xsd:nonPositiveInteger` range entails `xsd:short` |
| `w3c-reflexive-property-001` | successful closure | W3C `New-Feature-ReflexiveProperty-001`, explicit named-individual reflexivity |
| `w3c-disjoint-data-properties-002` | successful closure | W3C `New-Feature-DisjointDataProperties-002`, list-based property-disjoint individual difference |
| `w3c-disjoint-object-properties-001` | successful closure | W3C `New-Feature-DisjointObjectProperties-001`, binary property-disjoint individual difference |
| `w3c-disjoint-object-properties-002` | successful closure | W3C `New-Feature-DisjointObjectProperties-002`, list-based property-disjoint individual difference |
| `w3c-functional-property-different-from` | successful closure | W3C `owl2-rl-rules-fp-differentFrom`, functional-property inequality preservation |
| `w3c-inverse-functional-property-different-from` | successful closure | W3C `owl2-rl-rules-ifp-differentFrom`, inverse-functional-property inequality preservation |
| `w3c-disjoint-classes-001` | successful closure | W3C `DisjointClasses-001`, binary class disjointness → complement-class witness |
| `w3c-disjoint-classes-003` | successful closure | W3C `DisjointClasses-003`, `owl:AllDisjointClasses` list → complement-class witnesses |
| `w3c-object-qcr-002` | successful closure | W3C `New-Feature-ObjectQCR-002`, qualified max-cardinality plus inequality → complement-class witness |
| `w3c-i5-26-010` | successful closure | W3C `WebOnt-I5.26-010`, object-property declaration → minimum-cardinality restriction witness |
| `w3c-i5-5-005` | successful closure | W3C `WebOnt-I5.5-005`, class declaration → singleton `owl:unionOf` witness |
| `w3c-i5-8-007` | countermodel certificate | W3C `WebOnt-I5.8-007`, `xsd:short` range does not entail `xsd:unsignedByte` range |
| `w3c-i4-6-004` | countermodel certificate | W3C `WebOnt-I4.6-004`, `owl:equivalentClass` does not entail `owl:sameAs` |
| `w3c-object-property-chain-bjp-004` | countermodel certificate | W3C `New-Feature-ObjectPropertyChain-BJP-004`, `p ∘ q ⊑ p` does not entail `p` transitive |
| `w3c-keys-004` | countermodel certificate | W3C `New-Feature-Keys-004`, a localized key does not equate a class member with an outsider |
| `w3c-keys-005` | consistency-model certificate | W3C `New-Feature-Keys-005`, a localized key does not make its property functional |
| `w3c-i5-26-001` | consistency-model certificate | W3C `WebOnt-I5.26-001`, an intersection class can also occur as a type object |
| `w3c-i5-26-002` | consistency-model certificate | W3C `WebOnt-I5.26-002`, an intersection class can also occur in `owl:equivalentClass` and as a type object |
| `w3c-i5-26-005` | consistency-model certificate | W3C `WebOnt-I5.26-005`, an intersection class can also occur in `owl:equivalentClass` and `owl:disjointWith` |
| `w3c-disjoint-with-003` through `-009` | consistency-model certificate | W3C `WebOnt-disjointWith-003` through `-009`, pure `owl:disjointWith` graphs admit the empty-class model |
| `w3c-description-logic-101` / `-103` / `-104` | contradiction-proof certificate | W3C DL inconsistency cases, an asserted member reaches both a class and its complement |
| `w3c-rl-anonymous-individual`, `w3c-rl-valid-oneof`, `w3c-rl-valid-rightside-allvaluesfrom` | consistency-model certificates | W3C RL Profile shapes, verified for RDF semantic consistency only |

The fifty-seven `w3c-*` fixtures are minimal, rule-relevant N-Triples projections of
the corresponding approved, RDF-Based OWL 2 RL test cases in the W3C archive's
[`profile-RL.rdf`](https://www.w3.org/2009/11/owl-test/profile-RL.rdf). They
retain the premise triples needed for the named rule conclusion or
contradiction; they are not a claim to execute each complete source ontology.
The source was retrieved from that static archive with SHA-256
`6415369555af022fedd0fe9a7d6b56eb274f89284e4109d7303540ec75c76988`.
Thirty-two use the normal complete closure; four datatype conflict fixtures
deliberately use the separate generalized datatype closure, whose exact
value-identity rules are opt-in; and `w3c-i5-8-007` / `w3c-i4-6-004` / `w3c-object-property-chain-bjp-004` use checked finite
countermodel certificates, as does `w3c-keys-004` for a localized key; `w3c-keys-005`, the three `w3c-i5-26-*` structure-sharing cases, `w3c-disjoint-with-003` through `-009`, and the three `w3c-rl-*` Profile shapes use checked finite consistency models; the three DL cases use a checked complement-class contradiction proof. They test only the exact forward conclusion, contradiction, consistency, or negative-entailment proof
represented by the OWL 2 RL/RDF rule table, or an explicitly labelled RDF-Based semantic supplement; other profile-RL entries that
require unrestricted OWL semantic reasoning are tracked as outside this
bounded rule engine.

`reasoner/functional/functional_test.odin` additionally runs four selected W3C
Functional Syntax mapping cases (`FS2RDF-different-individuals-2-ar` / `-3-ar`,
`FS2RDF-no-builtin-prefixes-ar`, and `FS2RDF-same-individual-2-ar`). They are
not N-Triples fixtures: their source strings verify the bounded mapper's prefix,
same-individual, and different-individual RDF encodings directly.

`reasoner/import/triple_sink_test.odin` additionally runs the RDF/XML source
shapes for `New-Feature-AnnotationAnnotations-001` and
`New-Feature-AxiomAnnotations-001`, including annotation and axiom reification
triples; they are document strings rather than N-Triples fixtures.
It also runs `WebOnt-AnnotationProperty-003` / `-004`,
`WebOnt-backwardCompatibleWith-002`, and `WebOnt-miscellaneous-303` through the
same default-graph adapter.

`reasoner/owlrl/import_closure_test.odin` additionally runs
`WebOnt-imports-011`: a local resolver supplies its root and support RDF/XML
documents to `import.load_rdfxml_import_closure`, then `materialize_all` proves
that `Socrates` has the imported `Mortal` type. This is offline import-closure
evidence, not network fetching or full ontology-document processing.

Fine-grained tests still own each individual rule direction, strict-RDF
literal-subject exclusions, every implemented false rule kind, and provenance
support ordering. This corpus adds cross-rule, parser-to-store scenarios; it
does not broaden the supported OWL profile.
