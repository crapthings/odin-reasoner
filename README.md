# odin-reasoner

An experimental, resource-bounded RDF forward-chaining reasoner for Odin.

The current implementation includes the Phase 0–4 foundation: an owned term
dictionary, a set-semantics triple fact store with indexed pattern matching, an
RDF parser sink that immediately interns callback values, and a bounded
semi-naive conjunctive-rule materializer with first-support provenance, and the
six-rule [RDFS Core profile](reasoner/rdfs/profile.md). It also has a separate,
forty-eight-rule [OWL 2 RL hierarchy, object-property, schema, value, equality, functional-property, and self-restriction seed](reasoner/owlrl/profile.md),
not full OWL 2 RL. It does not claim complete RDFS, OWL, RIF, named graphs, persistence,
transactions, or network support. The optional read-only default-graph SPARQL
integration lives in [adapter/sparql](adapter/sparql); it does not make the core
depend on SPARQL. See the RDFS profile's
[conformance ledger](reasoner/rdfs/conformance-ledger.md).

The OWL profile can also produce an owned, evidence-carrying consistency report
after closure materialization for its implemented false rules, including class
disjointness, complements, `owl:AllDisjointClasses`, and
`owl:AllDisjointProperties`, and negative property assertions; an inconsistent
closure is reported explicitly rather than silently discarded. It also detects
`owl:AllDifferent` member lists contradicted by equality and instances of
`owl:Nothing`.

Its optional `materialize_one_of`, `materialize_intersection`,
`materialize_union`, and `materialize_property_chains` paths transactionally
materialize well-formed `owl:oneOf`, `owl:intersectionOf`, `owl:unionOf`, and
two-or-more-property `owl:propertyChainAxiom` RDF lists under explicit resource
limits.

## Dependency direction

```text
odin-reasoner --> odin-rdf
```

Core packages import only the public `odin-rdf:rdf` package. A future SPARQL
snapshot adapter will be a separate optional integration package; the core will
not import `odin-sparql`.

## Build

From this repository, with the adjacent `odin-rdf` checkout available:

```sh
odin check reasoner -no-entry-point -collection:odin-rdf=../odin-rdf
odin test reasoner -collection:odin-rdf=../odin-rdf
```

The API is experimental during `0.x`. See [docs/architecture.md](docs/architecture.md)
for ownership, fact identity, resource limits, and error behavior, and
[ROADMAP.md](ROADMAP.md) for the staged scope.
