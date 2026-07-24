// Reproducible baseline for the Phase 1 fact-store matching paths.
package main

import "core:fmt"
import "core:os"
import "core:time"
import rdf "odin-rdf:rdf"
import store "../../reasoner/store"

FACTS  :: #config(BENCH_FACTS, 50_000)
ROUNDS :: #config(BENCH_ROUNDS, 3)

count_sink :: proc(_: store.Fact_ID, _: store.Fact, _: store.Origin, user_data: rawptr) -> bool {
	(cast(^int)user_data)^ += 1
	return true
}

run_match :: proc(target: ^store.Store, pattern: store.Pattern, label: string, expected: int) {
	best := f64(1e30)
	iterations := expected == 1 ? 100_000 : 1
	matched_per_measurement := expected * iterations
	for _ in 0..<ROUNDS {
		count := 0
		started := time.now()
		result: store.Match_Result
		for _ in 0..<iterations {
			result = store.match(target, pattern, count_sink, &count)
			if result.error != .None || result.stopped do break
		}
		seconds := time.duration_seconds(time.since(started))
		if result.error != .None || result.stopped || count != matched_per_measurement {
			fmt.eprintf("%s benchmark failed: %v, %d matches\n", label, result.error, count)
			os.exit(1)
		}
		best = min(best, seconds)
	}
	fmt.printf("%s: %.2f M facts/s (%d matching facts per measurement)\n", label, f64(matched_per_measurement) / best / 1e6, expected)
}

main :: proc() {
	if FACTS <= 0 || ROUNDS <= 0 {
		fmt.eprintln("BENCH_FACTS and BENCH_ROUNDS must be positive")
		return
	}
	target: store.Store
	if error := store.init(&target, {max_terms = FACTS + 2, max_facts = FACTS}); error != .None {
		fmt.eprintln(store.error_message(error))
		return
	}
	defer store.destroy(&target)
	for index in 0..<FACTS {
		triple := rdf.Triple{
			subject = rdf.blank_node("node", rdf.Blank_Node_Scope(index + 1)),
			predicate = rdf.iri("urn:predicate"),
			object = rdf.iri("urn:object"),
		}
		if added, error := store.insert_triple(&target, triple); !added || error != .None {
			fmt.eprintln("fact admission failed", store.error_message(error))
			return
		}
	}
	_, fact, _, _ := store.fact_at(&target, 0)
	run_match(&target, {predicate = fact.predicate}, "predicate index", FACTS)
	run_match(&target, {subject = fact.subject, predicate = fact.predicate, object = fact.object}, "exact lookup", 1)
}
