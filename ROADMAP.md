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

## Phase 5 — bounded OWL 2 RL/RDF profile — complete

`reasoner/owlrl` composes RDFS Core with fifty-three direct W3C OWL 2 RL/RDF
rule directions, plus explicitly labelled RDF-Based semantic supplements. Its
bounded, transactional `materialize_all` closure combines static rules with
`owl:oneOf`, `owl:intersectionOf`, `owl:unionOf`, `owl:hasKey`, and bounded
`owl:propertyChainAxiom` materialization; it retains first-support provenance
for both static and list-derived conclusions. Checked closure reports the
implemented equality, disjointness, cardinality, negative-assertion, and
datatype contradictions without discarding a successful closure.

The [rule-cluster conformance ledger](reasoner/owlrl/conformance-ledger.md)
maps every supported direction to a local gate. All 68 Approved + RDF-Based
entries from the pinned W3C Profile-RL archive have executable evidence, as
recorded in the [W3C matrix](reasoner/owlrl/w3c-profile-rl-matrix.md). This is
not a claim of complete OWL 2 conformance: unrestricted model-theoretic
entailment, profile-document validation, general ontology-document processing,
and datatype relations not supplied exactly by `odin-rdf` remain outside this
bounded profile.

## Deliberately deferred

Broader OWL document support, profile validation, unrestricted datatype and
model-theoretic semantics, a dedicated OWL 2 EL classifier, OWL 2 QL query
rewriting/OBDA, DL or Full reasoning, RIF, named graphs, persistent stores,
transactions, SPARQL Update, protocol/HTTP, and extracting a shared graph-store
repository remain out of scope until their dedicated milestones. See [the OWL
profile decision](docs/owl-profiles.md) for the workload and architecture
criteria required to open an EL or QL milestone.
