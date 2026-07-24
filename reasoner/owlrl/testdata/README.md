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

Fine-grained tests still own each individual rule direction, strict-RDF
literal-subject exclusions, every implemented false rule kind, and provenance
support ordering. This corpus adds cross-rule, parser-to-store scenarios; it
does not broaden the supported OWL profile.
