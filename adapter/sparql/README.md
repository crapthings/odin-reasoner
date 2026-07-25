# SPARQL closure snapshot adapter

`sparql_adapter.Snapshot` is the only package in this repository that imports
`odin-sparql`. `init` copies the current reasoner closure into owned
default-graph quads, while `adopt_store` transfers a finished Store without a
second copy; both expose a borrowed `sparql/dataset.View` through `view`.

The snapshot is immutable and independent of the source `store.Store`; the
source store and RDFS profile may be destroyed after `init` returns. Terms
delivered by scans are borrowed from `Snapshot` and remain valid only until
`destroy`.

`init` accepts `Options{max_quads = ...}`. Zero disables that bound; a positive
limit rejects an oversized closure with `Quad_Limit` and destroys the incomplete
copy, so callers never receive a partial snapshot.

Only the default graph is supported. A `Named` or `Any_Named` scan is rejected
with `dataset.Invalid_View`, rather than silently treating a default graph as a
named graph. A sink returning `false` stops successfully and is never mapped to
an adapter failure.

`indexed_view(&store)` is a separate, borrowed default-graph View for callers
that keep a completed `store.Store` alive and do not mutate it during query
execution. It reuses the store's owned terms and match indexes without making
a second closure copy. It is deliberately **not** an immutable snapshot and
cannot outlive the store; use `Snapshot` when source independence is required.

`adopt_store(&snapshot, &store)` is the no-copy immutable option once
materialization is complete: it transfers the Store into `Snapshot`, resets the
source handle, and serves the same default-graph indexed scans through
`view(&snapshot)`. The adopted Store is private to the Snapshot, so callers
cannot mutate it through this adapter. It still does not add named-graph
support or change the adapter's error surface.

The integration suite also materializes an OWL 2 RL `owl:inverseOf` conclusion,
queries it through the borrowed `indexed_view`, then adopts the same completed
Store and verifies the immutable Snapshot returns the same SPARQL result.
It separately runs W3C `WebOnt-imports-011` end to end: local RDF/XML import
resolution, OWL RL materialization, Store adoption, and an `ASK` of the imported
class entailment.

Build with the adjacent named collections (the `odin-graph` collection is a
transitive dependency of `odin-sparql`):

```sh
odin test adapter/sparql \
  -collection:odin-rdf=../odin-rdf \
  -collection:odin-sparql=../odin-sparql \
  -collection:odin-graph=../odin-graph
```
