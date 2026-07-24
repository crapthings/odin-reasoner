# OWL profile decision

## Current decision

`odin-reasoner` is a bounded, forward-chaining **OWL 2 RL seed** for
application-owned RDF facts. It is not an implementation of multiple OWL
profiles and it does not claim complete OWL 2 RL conformance. The exact rule
surface, strict-RDF restrictions, limits, and local tests live in the
[OWL RL profile](../reasoner/owlrl/profile.md) and its
[conformance ledger](../reasoner/owlrl/conformance-ledger.md).

This choice fits the current architecture: indexed finite facts, transactional
materialization, evidence for first derivations, and an optional immutable
SPARQL closure snapshot. It fits applications that want inspectable rule-based
closure over data they own.

The [W3C OWL 2 Profiles Recommendation](https://www.w3.org/TR/owl2-profiles/)
defines EL, QL, and RL as independent profiles: none is a general replacement
or superset of another. A future profile therefore needs its own workload case,
algorithm, API boundary, and conformance gate.

## Selection guide

| Need | Appropriate direction | Status here |
| --- | --- | --- |
| Finite RDF closure, business-rule integration, provenance, and materialized query snapshots | Continue the bounded OWL 2 RL seed | Current product direction |
| Very large class/property taxonomies and scalable classification | Consider a dedicated OWL 2 EL profile | Not implemented |
| Ontology-mediated query answering over relational data, with query rewriting to SQL | Consider a QL/OBDA adapter | Not implemented |
| General description-logic reasoning over broad OWL constructs | A separate DL-oriented reasoner | Out of scope |
| Arbitrary RDF/OWL metamodeling without decidable-reasoning guarantees | OWL Full-style processing | Out of scope |

OWL Lite, OWL DL, and OWL Full are historical OWL 1 sublanguages. They do not
define a staged upgrade path for this repository. In particular, adding a few
rules must never be presented as DL or Full support.

## What the current RL direction does and does not mean

The current profile uses a rule/materialization model, which matches OWL 2 RL's
intended rule-engine use. It does **not** follow that every OWL 2 RL rule,
datatype behavior, or RDF-Based Semantics consequence is implemented. The
bounded seed explicitly excludes, among other areas, `owl:hasKey`, cardinality,
datatype entailment and false rules, and several list-related false rules.

Similarly, a successful `materialize_all` result is a complete closure only for
the documented seed and configured limits. It is not a generic ontology
classifier, a SQL query rewriter, or proof of OWL document conformance.

## Entry criteria for a new profile

### OWL 2 EL

Open an EL milestone only when a real workload is dominated by very large
class/property hierarchies and needs classification beyond the current RL seed.
The milestone must define an EL-specific algorithm and data model, rather than
adding arbitrary EL constructs to `owlrl`; it must also supply a separate
profile document, fixture corpus, external vectors, and performance baseline.

### OWL 2 QL / OBDA

Open a QL milestone only when a relational source of record and SQL-oriented
query answering are concrete requirements. Its product is query rewriting and
mapping management, not another in-memory closure routine. Any future adapter
must remain outside `reasoner/term`, `reasoner/store`, and `reasoner/rule`,
preserving the core's lack of storage, network, and database dependencies.

### DL or Full

There is no planned DL or Full milestone. A proposal would need a distinct user
need, semantic contract, termination/error policy, and a reasoner strategy that
does not weaken the bounded RL guarantees by accident.

## Architecture rule

The owned term dictionary, strict triple store, parser-import boundary, and
semi-naive rule engine can remain shared foundations where their contracts fit.
Profile-specific semantics must be isolated in separately named packages and
must not silently widen `owlrl`'s API or its conformance claim. Query rewriting,
SQL mappings, persistence, and remote I/O stay in outer adapters.
