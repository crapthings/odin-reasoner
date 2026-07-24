# SPARQL closure snapshot adapter

`sparql_adapter.Snapshot` is the only package in this repository that imports
`odin-sparql`. It copies the current reasoner closure into owned default-graph
quads and exposes a borrowed `sparql/dataset.View` through `view`.

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

Build with both adjacent named collections:

```sh
odin test adapter/sparql \
  -collection:odin-rdf=../odin-rdf \
  -collection:odin-sparql=../odin-sparql
```
