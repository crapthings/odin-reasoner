# Changelog

This project follows [Semantic Versioning](https://semver.org/). Before 1.0,
new capabilities may require a minor version and callers should pin releases.

## Unreleased

## 0.1.0 - 2026-07-24

- First public release of a bounded, forward-chaining RDF reasoner built on
  `odin-rdf` terms and parser callbacks.
- Provide the documented six-rule RDFS Core profile: subclass, subproperty,
  domain, range, and transitivity. It deliberately excludes complete RDFS,
  axiomatic triples, datatype entailment, and container vocabulary rules.
- Provide a bounded OWL 2 RL seed with documented static and RDF-list rule
  families, first-support provenance, and consistency reports for implemented
  false rules. It is not a complete OWL 2 RL, DL, or Full implementation.
- Provide owned term dictionaries, set-semantics indexed triple storage,
  transactional bounded materialization, and a parser-to-store import boundary.
- Provide an optional immutable default-graph SPARQL snapshot adapter. Named
  graph scans are explicitly rejected and the reasoner core has no SPARQL
  dependency.

## Compatibility notes

`odin-reasoner` is pre-1.0. The public RDFS/OWL profiles, resource limits,
term and blank-node identity, ownership, provenance, and snapshot boundaries
are documented contracts; callers should retain fixtures when upgrading. The
project supplies no persistent graph store, networking, SPARQL Update, or
complete RDF/OWL conformance claim.
