# RDFS Core conformance ledger

## Implemented local gate

`reasoner/rdfs/profile_test.odin` covers the six declared rules, subclass and
subproperty composition, recursion/cycles, duplicate closure, blank nodes, and
literal objects whose derived triples remain strict RDF.

## Pinned W3C RDF Semantics vectors

`profile_test.odin:test_pinned_w3c_rdfs_subproperty_semantics_vector` embeds
the seven normalized statement records from the W3C RDF 1.1 Semantics vector
[`rdfs-subPropertyOf-semantics/test001.nt`](https://github.com/w3c/rdf-tests/blob/main/rdf/rdf11/rdf-mt/rdfs-subPropertyOf-semantics/test001.nt)
and asserts all four records in its
[`test002.nt`](https://github.com/w3c/rdf-tests/blob/main/rdf/rdf11/rdf-mt/rdfs-subPropertyOf-semantics/test002.nt)
conclusion. It is listed by the official
[RDF Schema and Semantics manifest](https://w3c.github.io/rdf-tests/rdf/rdf11/rdf-mt/)
as an approved RDFS positive-entailment test. The local fixture deliberately
contains only RDF statements, excluding the source's comments and historical
metadata; its content is fixed in the test source. No unrecorded source hash is
claimed.

`profile_test.odin:test_pinned_w3c_rdfs_cycle_vectors_terminate_and_close`
embeds the statement records of the following approved RDFS positive-entailment
inputs, normalized from Turtle to N-Triples so they can pass through the local
application-owned triple boundary:

- [`rdfs-no-cycles-in-subClassOf/test001.ttl`](https://github.com/w3c/rdf-tests/blob/main/rdf/rdf11/rdf-mt/rdfs-no-cycles-in-subClassOf/test001.ttl)
- [`rdfs-no-cycles-in-subPropertyOf/test001.ttl`](https://github.com/w3c/rdf-tests/blob/main/rdf/rdf11/rdf-mt/rdfs-no-cycles-in-subPropertyOf/test001.ttl)

Their paired N-Triples conclusions are the corresponding asserted statement
sets; the local gate also checks that each two-node cycle derives its two
reflexive closure statements and reaches fixpoint. This validates cycle handling
without claiming the W3C suite's omitted axiomatic closure.

The suite has many RDFS cases outside this six-rule profile—axiomatic triples,
container membership, datatype and inconsistency semantics, and non-entailment
classification—so they are not claimed as passing. Add a mapped vector only
when its entire asserted conclusion is expressible by this profile.

The formal RDFS-RANGE conclusion with a literal object has a literal subject;
the current strict RDF-triple/N-Triples boundary cannot represent it. Such cases
are excluded as documented in [profile.md](profile.md), rather than silently
claiming full RDFS entailment.
