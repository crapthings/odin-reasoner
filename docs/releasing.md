# Releasing odin-reasoner

`odin-reasoner` is pre-1.0. A release is an immutable evidence statement for
its documented rule profiles and public boundaries, not a claim of complete
RDFS or OWL conformance.

## Prepare

- Select the semantic version and exact released `odin-rdf` revision.
- Update `README.md`, `CHANGELOG.md`, profiles, conformance ledgers, and API
  boundary documentation for every user-observable change.
- Run `git diff --check`; release only a clean, reviewed `main` commit.
- Record the Odin compiler, platform, component revisions, and retained test
  output with the release evidence.

## Verify

At minimum, run the public core and optional snapshot paths:

```sh
odin check reasoner -no-entry-point -collection:odin-rdf=../odin-rdf
odin test reasoner -collection:odin-rdf=../odin-rdf
odin test adapter/sparql \
  -collection:odin-rdf=../odin-rdf \
  -collection:odin-sparql=../odin-sparql
```

Run every profile package and its declared fixture corpus before releasing a
profile change. Review relevant resource-limit, ownership, blank-node,
provenance, and snapshot tests whenever their boundary changes.

The repository `ci` workflow repeats the core, profile, and optional SPARQL
adapter tests on Ubuntu, macOS, and Windows. Its Ubuntu quality job also runs
strict checks and AddressSanitizer. A candidate release must have that workflow
green on the exact commit; Pages deployment is documentation evidence only.

## Publish

- Confirm relevant CI is green on the exact candidate commit.
- Create one annotated immutable `vX.Y.Z` tag and push it with `main`.
- Publish non-draft release notes covering supported profiles, exclusions,
  component revisions, limits, and migration notes.
- Verify the local tag, `origin/main`, and the GitHub Release target resolve to
  the same commit. Never move a published tag; supersede errors with a new
  release.
