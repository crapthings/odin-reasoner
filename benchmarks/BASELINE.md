# Phase 1 match baseline

Recorded 2026-07-24 on macOS 15.7.7 with Odin `dev-2026-07:819fdc7a8`:

```text
odin run benchmarks/match -collection:odin-rdf=../odin-rdf \
  -define:BENCH_FACTS=50000 -define:BENCH_ROUNDS=3

predicate index: 94.16 M facts/s (50000 matching facts per measurement)
exact lookup: 10.05 M facts/s (1 matching facts per measurement)
```

This is a reproducibility reference only, not a performance guarantee or API
constraint. The exact lookup is repeated inside the benchmark to exceed the
clock's resolution.
