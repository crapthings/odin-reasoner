# Baseline benchmarks

`match/main.odin` records the Phase 1 indexed scan baseline without imposing a
performance number on the experimental API:

```sh
odin run benchmarks/match -collection:odin-rdf=../odin-rdf
```

The benchmark admits `BENCH_FACTS` distinct blank-node facts, then measures a
one-constant predicate scan and a three-constant exact lookup. Run it on the
target machine and record compiler revision, options, and results with any
performance comparison; defaults are 50,000 facts and three rounds.
