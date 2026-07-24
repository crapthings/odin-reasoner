# Roadmap

## Phase 0 — repository contract and compilable skeleton — complete

Complete when the repository documents its boundaries, compiles against the
named `odin-rdf` collection, and has a smoke test.

## Phase 1 — owned terms and incremental facts — complete

Complete when `reasoner/term` owns and interns RDF terms, `reasoner/store`
deduplicates and indexes triples, and `reasoner/import` safely accepts parser
sink values under explicit term, lexical-byte, and fact limits.

## Phase 2 — rule IR and semi-naive engine — complete

Provides a minimal conjunctive rule IR, delta-driven evaluation, bounded
fixpoint handling, first-support provenance, and naive-baseline tests. No RIF
parser is implied.

## Phase 3 — RDFS Core materializer — complete

Implements and tests only the documented RDFS Core rule table: subclass,
subproperty, transitivity, domain, and range. The conformance ledger pins three
compatible approved W3C RDFS positive-entailment vectors; it does not imply
axiomatic triples, datatype entailment, or complete RDFS.

## Phase 4 — SPARQL closure adapter — complete

`adapter/sparql` provides an owned, read-only default-graph closure snapshot
through public `dataset.View`/`custom_view`. It does not participate in
materialization and explicitly rejects named graph scans.

## Phase 5 — OWL 2 RL hierarchy seed — in progress

`reasoner/owlrl` composes RDFS Core with forty-eight direct W3C OWL 2 RL rules
for class/property equivalence (including schema closure), inverse/symmetric/
transitive object properties, schema domain/range propagation, and finite value
restrictions, strict-RDF-representable equality closure, and functional/
inverse-functional properties and typed-boolean `owl:hasSelf` restrictions. It also reports evidence-carrying conflicts for
sameAs/differentFrom, class/property disjointness, complement classes,
`owl:AllDisjointClasses`, `owl:AllDisjointProperties`, irreflexive, and
asymmetric properties, and negative property assertions. It deliberately excludes
RDF-list and datatype inconsistency, while supporting `owl:AllDifferent`
member-list conflicts,
cardinality restrictions, generalized-RDF literal-subject equality, and every
other OWL 2 RL rule cluster until each has its own profile and conformance gate.
The profile now also has a bounded RDF-list decoder as infrastructure; list
dependent entailment starts with transactional `owl:oneOf`,
`owl:intersectionOf`, `owl:unionOf`, and bounded `owl:propertyChainAxiom`
materialization. `materialize_all` now combines the static table and all four
dynamic list families into one bounded, transactional supported-closure entry
point. It retains first-support provenance for static and dynamic facts, while
the remaining Phase 5 work is rule-cluster conformance ledgers before expanding
OWL scope.

## Deliberately deferred

Additional OWL 2 RL rule clusters, RIF, named graphs, persistent stores,
transactions, SPARQL Update, protocol/HTTP, and extracting a shared graph-store
repository remain out of scope until their dedicated milestones.
