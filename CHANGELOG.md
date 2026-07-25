# Changelog

This project follows [Semantic Versioning](https://semver.org/). Before 1.0,
new capabilities may require a minor version and callers should pin releases.

## Unreleased

## 0.5.0 - 2026-07-25

- Add a bounded RDF-Based numeric range-intersection supplement: two
  nonempty, modeled integer datatype ranges on the same property can entail a
  named range containing their intersection. Pin W3C `WebOnt-I5.8-008` and
  `WebOnt-I5.8-009`, raising the offline approved RDF-Based fixture selection
  from 24 to 26 cases.
- Require the matching `odin-rdf` `v0.32.0` integer-interval behavior in CI.
  The new closure stays deliberately conservative: empty intersections and
  decimal, float, double, and unmodeled datatype families produce no range
  inference.

## 0.4.0 - 2026-07-25

- Add an offline, pinned W3C RDF-Based OWL 2 RL regression corpus with
  twenty-four rule-relevant fixtures and a complete current-scope matrix for
  the remaining approved archive cases. The suite is evidence for the bounded
  forward closure, not a claim of complete OWL entailment.
- Extend the documented RDF-Based supplement surface with `owl:differentFrom`
  symmetry, the exact numeric datatype hierarchy, explicit named-individual
  reflexive-property closure, and a two-step self property-chain transitivity
  consequence. Strict RDF remains the default, and generalized datatype heads
  remain opt-in.
- Require the `odin-rdf` `v0.31.2` data-value identity behavior in CI so
  signed-zero and string-to-numeric datatype contradictions are tested against
  the matching dependency revision.

## 0.3.0 - 2026-07-24

- Add `adapter/sparql.adopt_store`, which transfers a finished reasoner Store
  into an immutable, indexed SPARQL Snapshot without a second RDF Dataset copy.

## 0.2.0 - 2026-07-24

- Add `adapter/sparql.indexed_view`, a borrowed default-graph SPARQL View over
  a caller-kept reasoner Store. It reuses store-owned terms and indexed match
  scans without replacing the independent immutable `Snapshot` contract.

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
