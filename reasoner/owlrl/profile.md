# OWL 2 RL hierarchy and object-property seed profile

This package is not a complete OWL 2 RL implementation. It composes the six
documented [RDFS Core rules](../rdfs/profile.md) with fifty-two direct OWL 2 RL
directions, represented by sixty static rules, from the [W3C OWL 2 RL/RDF
rules](https://www.w3.org/TR/owl2-profiles/#Reasoning_in_OWL_2_RL_and_RDF_Graphs_Using_Rules):

The [conformance ledger](conformance-ledger.md) maps every implemented static
and dynamic direction to local evidence and its strict-RDF/resource boundary.

| ID | Rule |
| --- | --- |
| `OWL-RL-CAX-EQC1` (101) | `C1 owl:equivalentClass C2`, `x rdf:type C1` → `x rdf:type C2` |
| `OWL-RL-CAX-EQC2` (102) | `C1 owl:equivalentClass C2`, `x rdf:type C2` → `x rdf:type C1` |
| `OWL-RL-PRP-EQP1` (103) | `P1 owl:equivalentProperty P2`, `x P1 y` → `x P2 y` |
| `OWL-RL-PRP-EQP2` (104) | `P1 owl:equivalentProperty P2`, `x P2 y` → `x P1 y` |
| `OWL-RL-PRP-INV1` (105) | `P1 owl:inverseOf P2`, `x P1 y` → `y P2 x` |
| `OWL-RL-PRP-INV2` (106) | `P1 owl:inverseOf P2`, `x P2 y` → `y P1 x` |
| `OWL-RL-PRP-SYMP` (107) | `P rdf:type owl:SymmetricProperty`, `x P y` → `y P x` |
| `OWL-RL-PRP-TRP` (108) | `P rdf:type owl:TransitiveProperty`, `x P y`, `y P z` → `x P z` |
| `OWL-RL-SCM-DOM1` (109) | `P rdfs:domain C1`, `C1 rdfs:subClassOf C2` → `P rdfs:domain C2` |
| `OWL-RL-SCM-DOM2` (110) | `P1 rdfs:subPropertyOf P2`, `P2 rdfs:domain C` → `P1 rdfs:domain C` |
| `OWL-RL-SCM-RNG1` (111) | `P rdfs:range C1`, `C1 rdfs:subClassOf C2` → `P rdfs:range C2` |
| `OWL-RL-SCM-RNG2` (112) | `P1 rdfs:subPropertyOf P2`, `P2 rdfs:range C` → `P1 rdfs:range C` |
| `OWL-RL-CLS-HV1` (113) | `R owl:hasValue y`, `R owl:onProperty P`, `x rdf:type R` → `x P y` |
| `OWL-RL-CLS-HV2` (114) | `R owl:hasValue y`, `R owl:onProperty P`, `x P y` → `x rdf:type R` |
| `OWL-RL-CLS-SVF1` (115) | `R owl:someValuesFrom C`, `R owl:onProperty P`, `x P y`, `y rdf:type C` → `x rdf:type R` |
| `OWL-RL-CLS-SVF2` (116) | `R owl:someValuesFrom owl:Thing`, `R owl:onProperty P`, `x P y` → `x rdf:type R` |
| `OWL-RL-CLS-AVF` (117) | `R owl:allValuesFrom C`, `R owl:onProperty P`, `x rdf:type R`, `x P y` → `y rdf:type C` |
| `OWL-RL-SCM-EQC1` (118) | `C1 owl:equivalentClass C2` → `C1 rdfs:subClassOf C2` |
| `OWL-RL-SCM-EQC1-REVERSE` (119) | `C1 owl:equivalentClass C2` → `C2 rdfs:subClassOf C1` |
| `OWL-RL-SCM-EQC2` (120) | `C1 rdfs:subClassOf C2`, `C2 rdfs:subClassOf C1` → `C1 owl:equivalentClass C2` |
| `OWL-RL-SCM-EQP1` (121) | `P1 owl:equivalentProperty P2` → `P1 rdfs:subPropertyOf P2` |
| `OWL-RL-SCM-EQP1-REVERSE` (122) | `P1 owl:equivalentProperty P2` → `P2 rdfs:subPropertyOf P1` |
| `OWL-RL-SCM-EQP2` (123) | `P1 rdfs:subPropertyOf P2`, `P2 rdfs:subPropertyOf P1` → `P1 owl:equivalentProperty P2` |
| `OWL-RL-SCM-HV` (124) | `R1 hasValue i/onProperty P1`, `R2 hasValue i/onProperty P2`, `P1 subPropertyOf P2` → `R1 subClassOf R2` |
| `OWL-RL-SCM-SVF1` (125) | `R1 someValuesFrom C1/onProperty P`, `R2 someValuesFrom C2/onProperty P`, `C1 subClassOf C2` → `R1 subClassOf R2` |
| `OWL-RL-SCM-SVF2` (126) | `R1 someValuesFrom C/onProperty P1`, `R2 someValuesFrom C/onProperty P2`, `P1 subPropertyOf P2` → `R1 subClassOf R2` |
| `OWL-RL-SCM-AVF1` (127) | `R1 allValuesFrom C1/onProperty P`, `R2 allValuesFrom C2/onProperty P`, `C1 subClassOf C2` → `R1 subClassOf R2` |
| `OWL-RL-SCM-AVF2` (128) | `R1 allValuesFrom C/onProperty P1`, `R2 allValuesFrom C/onProperty P2`, `P1 subPropertyOf P2` → `R2 subClassOf R1` |
| `OWL-RL-EQ-REF-SUBJECT` (129) | Any `s p o` → `s owl:sameAs s` |
| `OWL-RL-EQ-REF-PREDICATE` (130) | Any `s p o` → `p owl:sameAs p` |
| `OWL-RL-EQ-REF-OBJECT` (131) | Any `s p o` → `o owl:sameAs o` when the strict RDF head is representable |
| `OWL-RL-EQ-SYM` (132) | `x owl:sameAs y` → `y owl:sameAs x` |
| `OWL-RL-EQ-TRANS` (133) | `x owl:sameAs y`, `y owl:sameAs z` → `x owl:sameAs z` |
| `OWL-RL-EQ-REP-SUBJECT` (134) | `s owl:sameAs s'`, `s p o` → `s' p o` |
| `OWL-RL-EQ-REP-PREDICATE` (135) | `p owl:sameAs p'`, `s p o` → `s p' o` |
| `OWL-RL-EQ-REP-OBJECT` (136) | `o owl:sameAs o'`, `s p o` → `s p o'` |
| `OWL-RL-PRP-FP` (137) | `P rdf:type owl:FunctionalProperty`, `x P y1`, `x P y2` → `y1 owl:sameAs y2` |
| `OWL-RL-PRP-IFP` (138) | `P rdf:type owl:InverseFunctionalProperty`, `x1 P y`, `x2 P y` → `x1 owl:sameAs x2` |
| `OWL-RL-PRP-AP` (158) | Every built-in OWL 2 annotation property → `rdf:type owl:AnnotationProperty` |
| `OWL-RL-CLS-HAS-SELF1` (139) | `R owl:hasSelf "true"^^xsd:boolean/onProperty P`, `x rdf:type R` → `x P x` |
| `OWL-RL-CLS-HAS-SELF2` (140) | `R owl:hasSelf "true"^^xsd:boolean/onProperty P`, `x P x` → `x rdf:type R` |
| `OWL-RL-CLS-MAXC2` (154) | `R owl:maxCardinality "1"^^xsd:nonNegativeInteger/onProperty P`, `x rdf:type R`, `x P y1`, `x P y2` → `y1 owl:sameAs y2` when its strict RDF head is representable |
| `OWL-RL-CLS-MAXQC3` (155) | `R owl:maxQualifiedCardinality "1"^^xsd:nonNegativeInteger/onProperty P/onClass C`, `x rdf:type R`, and two `C` values of `P` → equality when its strict RDF head is representable |
| `OWL-RL-CLS-MAXQC4` (156) | `R owl:maxQualifiedCardinality "1"^^xsd:nonNegativeInteger/onProperty P/onClass owl:Thing`, `x rdf:type R`, `x P y1`, `x P y2` → equality when its strict RDF head is representable |
| `OWL-RL-SCM-CLS-SUBCLASS` (141) | `C rdf:type owl:Class` → `C rdfs:subClassOf C` |
| `OWL-RL-SCM-CLS-EQUIVALENT` (142) | `C rdf:type owl:Class` → `C owl:equivalentClass C` |
| `OWL-RL-SCM-CLS-THING` (143) | `C rdf:type owl:Class` → `C rdfs:subClassOf owl:Thing` |
| `OWL-RL-SCM-CLS-NOTHING` (144) | `C rdf:type owl:Class` → `owl:Nothing rdfs:subClassOf C` |
| `OWL-RL-SCM-OP-SUBPROPERTY` (145) | `P rdf:type owl:ObjectProperty` → `P rdfs:subPropertyOf P` |
| `OWL-RL-SCM-OP-EQUIVALENT` (146) | `P rdf:type owl:ObjectProperty` → `P owl:equivalentProperty P` |
| `OWL-RL-SCM-DP-SUBPROPERTY` (147) | `P rdf:type owl:DatatypeProperty` → `P rdfs:subPropertyOf P` |
| `OWL-RL-SCM-DP-EQUIVALENT` (148) | `P rdf:type owl:DatatypeProperty` → `P owl:equivalentProperty P` |

The RDFS and OWL rules are passed to one semi-naive materializer, so either
cluster can drive the other to a single bounded fixpoint. `init` reserves all
sixty-three RDFS/OWL vocabulary terms as one store batch before building rules.

## Complete supported closure

`materialize_all` is the public entry point when an application needs every
currently supported entailment family. It alternates the static sixty-six-rule
RDFS/OWL table with `owl:oneOf`, `owl:intersectionOf`, `owl:unionOf`,
`owl:propertyChainAxiom`, and `owl:hasKey` expansion until a joint fixpoint. It uses one cloned
working store and commits inferred facts only after success: any static-rule,
list, path-frontier, derivation, or outer-round error leaves the caller's store
unchanged. Its `max_derivations` and `max_rounds` limits apply across all six
phases; `max_list_items` applies to every decoded collection, and
`max_path_states` applies to each property-chain frontier.

| ID | Dynamic rule direction |
| --- | --- |
| `OWL-RL-CLS-OO` (149) | List member → enclosing `owl:oneOf` class instance |
| `OWL-RL-CLS-INT1` (150) | All member-class instances → intersection instance |
| `OWL-RL-CLS-INT2` (151) | Intersection instance → every member-class instance |
| `OWL-RL-CLS-UNI` (152) | Member-class instance → enclosing union instance |
| `OWL-RL-PRP-SPO2` (153) | Complete property-list path → declared chain property |
| `OWL-RL-PRP-KEY` (157) | Matching every property in an `owl:hasKey` RDF list identifies two class instances |

The focused `materialize`, `materialize_one_of`, `materialize_intersection`,
`materialize_union`, and `materialize_property_chains` entry points remain for
small, isolated profiles. `materialize_all` exposes complete first-support
evidence through `closure_derivation_count` and `closure_derivation_at`.
Static conclusions retain their rule-engine supports; list conclusions retain
the declaration, every decoded `rdf:first`/`rdf:rest` fact, and the participating
type or property-path facts. These views borrow from the profile's latest
successful complete closure. A failed call leaves the preceding successful
closure provenance intact. The focused dynamic entry points still expose only
inferred origin, so the legacy `Materializer` is cleared after a successful
`materialize_all` rather than presenting stale partial evidence.

The strict RDF triple store cannot retain a literal subject. Consequently, an
inverse or symmetric rule match with a literal in the object position has an
unrepresentable reverse head and is omitted, just as RDFS range omits a formal
literal-subject conclusion. The `allValuesFrom` conclusion has the same boundary
when its property object is a literal. Other literal-object property assertions,
including `hasValue`, remain available to the non-reversing rules.

Equality follows the W3C reflexive, symmetric, transitive, and replacement rule
table for every strict RDF head the store can represent. A literal object cannot
be the subject of an RDF triple, so its reflexive/symmetric equality statement
and subject replacement are omitted; equality can still replace it in object
position. This is a strict RDF boundary, not a claim of generalized-RDF or full
OWL 2 RL equality support.

`FunctionalProperty` follows that same boundary when either value is a literal:
the formal equality head would have a literal subject and is skipped. An
`InverseFunctionalProperty` conclusion identifies strict RDF subjects and is
therefore representable.

## Consistency report

`materialize_checked` first reaches the static profile's materialization
fixpoint, then returns a borrowed consistency status plus an owned `Report`.
`materialize_all_checked` does the same after the complete supported static and
RDF-list closure. A nonempty report makes the corresponding `consistent` flag
false without discarding the completed closure or its provenance. Each report
record carries closure `Fact_ID` evidence. `check_consistency` also works on an
existing closure.

The report currently implements `eq-diff1`, class/property disjointness,
complement classes, `owl:AllDisjointClasses`, `owl:AllDisjointProperties`,
irreflexive properties, asymmetric properties, and both forms of
`owl:NegativePropertyAssertion`, plus `owl:AllDifferent`. An all-disjoint
violation retains the group type, its `owl:members` fact, and both conflicting
facts. A negative assertion retains its type, source, assertion property,
target, and conflicting property fact. An all-different violation retains its
group type, members fact, and equality fact. Malformed all-disjoint or
all-different member lists clear the report and return
`List_Error`. `max_violations` bounds retained evidence; on hitting it, the
report is cleared and `Violation_Limit` is returned, so a prefix cannot be
mistaken for complete analysis.

Any `rdf:type owl:Nothing` fact is also reported as a one-fact `cls-nothing2`
contradiction after closure materialization.

## RDF list decoder

`read_list` is a non-mutating, owned `Term_ID` decoder for a well-formed
`rdf:first`/`rdf:rest` chain ending at `rdf:nil`. It validates one first and one
rest per node, detects cycles, and clears output on malformed input or an item
limit.

## `owl:oneOf` materialization

`materialize_one_of` implements the list-dependent `cls-oo` direction: each
member of a valid `C owl:oneOf (...)` list is inferred as `rdf:type C`. It is
the focused counterpart to `materialize_all`: it alternates this dynamic phase
with the static RDFS/OWL rule table in a cloned store until joint fixpoint and
commits inferred facts only on success. The dynamic phase has explicit
list-item, outer-round, and total-derivation limits. Malformed lists or a
configured limit leave the caller's store unchanged. Dynamic oneOf facts
currently do not enter `Materializer` provenance; their origin is still
`Inferred` in the store.

## `owl:intersectionOf` materialization

`materialize_intersection` implements both list-dependent class directions:
an instance of every class in a valid `C owl:intersectionOf (...)` list is
inferred as `rdf:type C`, and each instance of `C` is inferred as an instance
of every listed class. It uses the same cloned-store, joint-fixpoint, and
commit-on-success boundary as `materialize_one_of`. Empty lists are rejected:
their OWL meaning requires `owl:Thing`, which this bounded strict-RDF profile
does not model. Dynamic intersection facts are stored as `Inferred` but do not
yet receive `Materializer` provenance.

## `owl:unionOf` materialization

`materialize_union` implements the W3C `cls-uni` direction: each instance of a
class in a valid `C owl:unionOf (...)` list is inferred as an instance of `C`.
It alternates this phase with the static RDFS/OWL table in a cloned store until
joint fixpoint and commits inferred facts only on success. A well-formed empty
list is accepted but creates no finite `cls-uni` conclusion; malformed lists
or configured limits leave the caller's store unchanged. Dynamic union facts
are stored as `Inferred` but do not yet receive `Materializer` provenance.

## `owl:propertyChainAxiom` materialization

`materialize_property_chains` implements the list-dependent `prp-spo2`
direction for chains of at least two IRI properties. It follows each complete
ordered path and infers its start/end pair using the declared property. The
working frontier retains each start with its own endpoint, so paths never mix
across different starts. It shares the cloned-store, joint-fixpoint, and
commit-on-success behavior of the other dynamic list entry points. In addition
to list, round, and derivation limits, `max_path_states` bounds each chain-hop
frontier. Empty, one-item, or non-IRI property lists are rejected. Dynamic
property-chain facts are stored as `Inferred` but do not yet receive
`Materializer` provenance.

Out of scope: RDF-list inconsistency rules, cardinality restrictions, datatype
inconsistency, schema self-axioms, and generalized RDF.
