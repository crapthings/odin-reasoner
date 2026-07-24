# RDFS Core profile

This package implements only these finite forward rules, with stable IDs:

| ID | Rule |
| --- | --- |
| `RDFS-SC` (1) | `C1 rdfs:subClassOf C2`, `x rdf:type C1` → `x rdf:type C2` |
| `RDFS-SC-TRANS` (2) | `C1 rdfs:subClassOf C2`, `C2 rdfs:subClassOf C3` → `C1 rdfs:subClassOf C3` |
| `RDFS-SP` (3) | `P1 rdfs:subPropertyOf P2`, `s P1 o` → `s P2 o` |
| `RDFS-SP-TRANS` (4) | `P1 rdfs:subPropertyOf P2`, `P2 rdfs:subPropertyOf P3` → `P1 rdfs:subPropertyOf P3` |
| `RDFS-DOMAIN` (5) | `P rdfs:domain C`, `s P o` → `s rdf:type C` |
| `RDFS-RANGE` (6) | `P rdfs:range C`, `s P o` → `o rdf:type C` |

It intentionally excludes RDFS axiomatic triples, container membership rules,
datatype entailment, D-entailment, generalized RDF, named graphs, and any
infinite vocabulary closure. It therefore must not be described merely as
“RDFS support” or as complete RDFS.

The Phase 1 store retains strict RDF 1.1 triples. Consequently, if `o` in an
RDFS-RANGE match is a literal, the formal conclusion `o rdf:type C` would have
a literal subject and cannot be represented or emitted as N-Triples; that head
is omitted. Literal objects remain fully supported by subproperty and other
rules whose derived triples remain strict RDF.

`Profile.init` interns the five vocabulary IRIs atomically with respect to the
store's term/lexical limits. `Profile.materialize` delegates to the transactional
working-snapshot rule materializer; on a configured resource-limit failure it
does not commit a partial closure.
