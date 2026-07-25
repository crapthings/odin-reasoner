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
| `w3c-reflexive-property-001` | successful closure | W3C `New-Feature-ReflexiveProperty-001`, explicit named-individual reflexivity |

The twenty-four `w3c-*` fixtures are minimal, rule-relevant N-Triples projections of
the corresponding approved, RDF-Based OWL 2 RL test cases in the W3C archive's
[`profile-RL.rdf`](https://www.w3.org/2009/11/owl-test/profile-RL.rdf). They
retain the premise triples needed for the named rule conclusion or
contradiction; they are not a claim to execute each complete source ontology.
The source was retrieved from that static archive with SHA-256
`6415369555af022fedd0fe9a7d6b56eb274f89284e4109d7303540ec75c76988`.
Twenty use the normal complete closure; the four datatype conflict fixtures
deliberately use the separate generalized datatype closure, whose exact
value-identity rules are opt-in. They test only the exact forward conclusion or contradiction
represented by the OWL 2 RL/RDF rule table; other profile-RL entries that
require unrestricted OWL semantic reasoning are tracked as outside this
bounded rule engine.

Fine-grained tests still own each individual rule direction, strict-RDF
literal-subject exclusions, every implemented false rule kind, and provenance
support ordering. This corpus adds cross-rule, parser-to-store scenarios; it
does not broaden the supported OWL profile.
