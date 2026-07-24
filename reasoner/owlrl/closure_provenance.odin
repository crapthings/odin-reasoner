package owlrl

import rule "../rule"
import store "../store"

// Closure_Derivation_View borrows its support slice from a Profile's latest
// successful materialize_all call. It remains valid until the next successful
// materialize_all call or profile destruction.
Closure_Derivation_View :: struct {
	fact_id:  store.Fact_ID,
	rule_id:  rule.Rule_ID,
	supports: []store.Fact_ID,
}

@(private) Closure_Derivation :: struct {
	fact_id:  store.Fact_ID,
	rule_id:  rule.Rule_ID,
	supports: [dynamic]store.Fact_ID,
}

// Closure_Provenance owns first-support records for the complete supported
// closure. It is staged privately during materialize_all and replaces the
// profile's previous record only after the closure commits successfully.
Closure_Provenance :: struct { derivations: [dynamic]Closure_Derivation }

@(private) init_closure_provenance :: proc(provenance: ^Closure_Provenance) {
	provenance^ = Closure_Provenance{derivations = make([dynamic]Closure_Derivation)}
}

@(private) clear_closure_provenance :: proc(provenance: ^Closure_Provenance) {
	for derivation in provenance.derivations do delete(derivation.supports)
	clear(&provenance.derivations)
}

@(private) destroy_closure_provenance :: proc(provenance: ^Closure_Provenance) {
	clear_closure_provenance(provenance)
	delete(provenance.derivations)
	provenance^ = {}
}

closure_derivation_count :: proc(profile: ^Profile) -> int {
	return len(profile.closure_provenance.derivations)
}

closure_derivation_at :: proc(profile: ^Profile, index: int) -> (Closure_Derivation_View, bool) {
	if index < 0 || index >= len(profile.closure_provenance.derivations) do return {}, false
	derivation := profile.closure_provenance.derivations[index]
	return {fact_id = derivation.fact_id, rule_id = derivation.rule_id, supports = derivation.supports[:]}, true
}

@(private) append_closure_derivation :: proc(provenance: ^Closure_Provenance, fact_id: store.Fact_ID, rule_id: rule.Rule_ID, supports: []store.Fact_ID) -> bool {
	owned := make([dynamic]store.Fact_ID, 0, len(supports))
	for support in supports {
		_, append_error := append(&owned, support)
		if append_error != nil {
			delete(owned)
			return false
		}
	}
	_, append_error := append(&provenance.derivations, Closure_Derivation{fact_id = fact_id, rule_id = rule_id, supports = owned})
	if append_error != nil {
		delete(owned)
		return false
	}
	return true
}

@(private) append_static_derivations :: proc(provenance: ^Closure_Provenance, materializer: ^rule.Materializer) -> bool {
	for index in 0..<rule.derivation_count(materializer) {
		derivation, found := rule.derivation_at(materializer, index)
		if !found || !append_closure_derivation(provenance, derivation.fact_id, derivation.rule_id, derivation.supports) do return false
	}
	return true
}

@(private) append_list_derivation :: proc(provenance: ^Closure_Provenance, fact_id: store.Fact_ID, rule_id: rule.Rule_ID, declaration_id: store.Fact_ID, list: ^List, extra_supports: []store.Fact_ID) -> bool {
	supports := make([dynamic]store.Fact_ID, 0, 1 + 2 * list_count(list) + len(extra_supports))
	defer delete(supports)
	_, append_error := append(&supports, declaration_id)
	if append_error != nil do return false
	for index in 0..<list_count(list) {
		first_id, first_found := list_first_fact_at(list, index)
		rest_id, rest_found := list_rest_fact_at(list, index)
		if !first_found || !rest_found do return false
		_, append_error = append(&supports, first_id)
		if append_error != nil do return false
		_, append_error = append(&supports, rest_id)
		if append_error != nil do return false
	}
	for support in extra_supports {
		_, append_error = append(&supports, support)
		if append_error != nil do return false
	}
	return append_closure_derivation(provenance, fact_id, rule_id, supports[:])
}
