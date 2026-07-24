# Architecture

## Package boundary

`reasoner/term`, `reasoner/store`, `reasoner/import`, and `reasoner/rule`
depend only on the public `odin-rdf:rdf` model. There is one triple graph; named
graphs are rejected by omission from the API. The store and rule engine are
experimental internal foundations, not a general graph-store package.

## Ownership and identity

An RDF parser sink may lend term strings only until the callback returns.
`import.triple_sink` calls `store.insert_triple`, which calls the dictionary and
copies every non-empty lexical field before it returns. `term.get` and
`store.triple_for` return *borrowed* `rdf.Term`/`rdf.Triple` values: their string
data remain valid only until `term.destroy`/`store.destroy`; callers must not
free them and must copy them to retain them beyond that lifetime.

Term identity is RDF term kind, lexical value, datatype, and language tag
(ASCII case-insensitive); blank nodes additionally use both scope and label.
Thus `_:x` from two parser calls does not merge, while equal labels in one parser
scope do merge. The dictionary retains the first spelling of an equal language
tag. All three term fields are copied, including the standard datatype constants.

Facts are `Term_ID` triples and have RDF graph set semantics. Inserting an
existing fact is a successful no-op. The first insertion's `Origin` is retained:
an asserted fact remains asserted if later encountered as inferred, and an
inferred fact remains inferred if later inserted again.

## Indexed matching

The store maintains fact lookup plus one- and two-position indexes for S, P, O,
SP, SO, and PO. `store.match` selects the most specific available index, so each
combination of constant and wildcard triple positions has a direct correct
path; three constants use the fact set lookup.

## Resource limits and errors

`Store_Options` exposes `max_terms`, `max_lexical_bytes`, and `max_facts`.
Zero disables that individual limit. Admission is checked before mutation for
all limit errors: a term, lexical-byte, or fact limit leaves the dictionary and
fact set unchanged. `Invalid_Term` and invalid triple structure are explicit
errors. Allocation failures are reported explicitly where Odin exposes them;
the MVP's resource-limit atomicity guarantee applies specifically to configured
admission limits, not to process-wide allocation failure.

`rule.Options` adds `max_derivations` and `max_rounds` at the materialization
boundary. No API silently truncates facts or matches: parser import stops its
source when store admission fails and exposes the exact store error via
`Sink_State`.

## Rule materialization and provenance

`rule.Rule` contains caller-owned body and head template slices. A template slot
is either a constant `Term_ID` or a rule-local `Variable_ID`; every head variable
must appear in the body, so the MVP does not create existential terms. Constants
that do not occur in asserted data can be admitted first with
`store.intern_term`.

`rule.materialize` evaluates each rule once for every possible delta body atom;
the remaining atoms match the indexed full working closure. A newly inserted
fact enters the next delta, and equality/deduplication remains entirely in the
fact store. This is set semantics, not SPARQL solution multiset semantics.

Materialization first clones the bounded store, including rule-only constants.
It commits inferred facts to the caller's store only after reaching fixpoint.
Thus a configured fact, round, or derivation limit returns an explicit error
without committing a partial closure. Allocation failures remain explicit but
are not a process-wide transaction guarantee. On success, `Materializer` owns
the first derivation for each newly inferred fact: its stable rule ID and ordered
support fact IDs. `derivation_at` returns a borrowed support slice valid until
the next call or `destroy`.

`reasoner/owlrl` composes the RDFS Core table and its explicitly documented
forty-eight-rule OWL 2 RL hierarchy/object-property/schema/value/equality/functional-property/self-restriction seed into one
`rule.materialize` invocation. The combined profile therefore has the same
transactional limit behavior: a joint fixpoint either commits in full or
returns the configured limit error without a partial RDFS/OWL closure.

The OWL profile's `materialize_checked` and `materialize_all_checked` keep
closure behavior separate from semantic consistency: they commit a successful
static or complete closure, then scan it for
implemented OWL 2 RL false rules (including class disjointness,
`owl:complementOf`, and list-backed `owl:AllDisjointClasses` /
`owl:AllDisjointProperties`, plus both negative property assertion forms) and
returns an owned report of fact-ID evidence. A nonempty report marks the result
inconsistent without erasing facts. The all-disjoint rules retain four fact IDs
and return `List_Error` with a cleared report if their member list is malformed;
negative property assertions retain five fact IDs.
The report has its own explicit `max_violations` limit; reaching it clears the
report and returns `Violation_Limit`, avoiding any ambiguous partial analysis.

For dynamic RDF-list rules, `store.clone` preserves stable term/fact IDs in an
independent working copy and `store.commit_inferred` transfers only successful
inferred facts back to that clone's source dictionary. The
`owlrl.materialize_all` is the complete supported-closure entry point. It uses
this boundary to alternate static rules with every supported RDF-list expansion
without committing a malformed-list or configured-limit prefix. Its focused
`materialize_one_of`, `materialize_intersection`, `materialize_union`, and
`materialize_property_chains` counterparts remain available when an application
intentionally wants one dynamic family only. Intersection rejects empty lists
because this profile does not model their `owl:Thing` meaning; union accepts an
empty list but has no finite forward conclusion; and strict property chains
require at least two IRI properties with a separate per-hop path-frontier bound.
`Materialize_All_Options.generalized_heads` extends the complete supported
closure to generalized RDF, including dynamic list heads, while asserted input
remains strict RDF.
`materialize_all` stages an owned closure-provenance ledger beside the working
store: every static fact copies its rule-engine support, while list facts record
the declaration, all decoded `rdf:first`/`rdf:rest` facts, and their type or
path supports. The ledger replaces the profile's previous successful complete
ledger only after inferred facts commit. `closure_derivation_at` returns a
borrowed support slice valid until the next successful complete closure or
`owlrl.destroy`; focused dynamic materializers retain their smaller origin-only
contract.

## Optional SPARQL integration

`adapter/sparql` is a separate package that imports `odin-sparql`; neither the
store, rule engine, nor RDFS profile does. `init` copies the completed closure
into an owned immutable `Snapshot`; `adopt_store` instead transfers a finished
Store into the Snapshot and retains its owned terms and indexes without a
second Dataset copy. Both expose the public `dataset.custom_view` boundary and
may outlive the source handle. The snapshot supports only default-graph scans:
`Named` and `Any_Named` modes return `dataset.Invalid_View` explicitly. Scan
early-stop is successful. `Snapshot.Options.max_quads` is an optional admission
bound for the copied form; an oversized closure returns `Quad_Limit` and
destroys the incomplete copy. Scan terms remain borrowed until
`sparql_adapter.destroy`.
