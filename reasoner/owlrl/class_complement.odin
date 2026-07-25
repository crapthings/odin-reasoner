package owlrl

import rdf "odin-rdf:rdf"
import rule "../rule"
import store "../store"
import term "../term"

// Class_Complement_Error_Code reports the bounded RDF-Based class-expression
// supplement. It constructs only the complement witnesses forced by a finite
// disjoint-class or max-qualified-cardinality proof; it is not a general OWL
// class-expression reasoner.
Class_Complement_Error_Code :: enum { None, Rule_Error, List_Error, Out_Of_Memory, Store_Error }

@(private) add_complement_fact :: proc(profile: ^Profile, target: ^store.Store, subject, predicate, object: term.Term_ID, remaining: int, added_count: ^int, generalized_heads: bool, provenance: ^Closure_Provenance, rule_id: rule.Rule_ID, supports: []store.Fact_ID) -> (Class_Complement_Error_Code, store.Error_Code) {
	fact := store.Fact{subject = subject, predicate = predicate, object = object}
	if store.contains(target, fact) do return .None, .None
	if remaining >= 0 && added_count^ >= remaining do return .Rule_Error, .None
	subject_term, subject_ok := store.get_term(target, subject)
	predicate_term, predicate_ok := store.get_term(target, predicate)
	object_term, object_ok := store.get_term(target, object)
	if !subject_ok || !predicate_ok || !object_ok do return .Store_Error, .Invalid_Fact
	if !generalized_heads && rdf.validate_triple_structure({subject_term, predicate_term, object_term}) != .None do return .None, .None
	added, insert_error := store.insert(target, fact, .Inferred)
	if insert_error != .None do return insert_error == .Out_Of_Memory ? .Out_Of_Memory : .Store_Error, insert_error
	if !added do return .None, .None
	added_count^ += 1
	fact_id := store.id_for_fact(target, fact)
	if fact_id == store.INVALID_FACT_ID || !append_closure_derivation(provenance, fact_id, rule_id, supports) do return .Out_Of_Memory, .Out_Of_Memory
	return .None, .None
}

@(private) complement_class_for :: proc(profile: ^Profile, target: ^store.Store, class: term.Term_ID) -> (term.Term_ID, Class_Complement_Error_Code, store.Error_Code) {
	for index in 0..<store.fact_count(target) {
		_, fact, _, found := store.fact_at(target, index)
		if !found do return term.INVALID_TERM_ID, .Store_Error, .Invalid_Fact
		if fact.predicate != profile.terms.complement_of || fact.object != class do continue
		candidate, candidate_found := store.get_term(target, fact.subject)
		if !candidate_found do return term.INVALID_TERM_ID, .Store_Error, .Invalid_Fact
		if candidate.kind != .Literal do return fact.subject, .None, .None
	}
	fresh, intern_error := store.intern_term(target, rdf.blank_node("owlrl-complement", rdf.new_blank_node_scope()))
	if intern_error != .None do return term.INVALID_TERM_ID, intern_error == .Out_Of_Memory ? .Out_Of_Memory : .Store_Error, intern_error
	return fresh, .None, .None
}

@(private) emit_complement_witness :: proc(profile: ^Profile, target: ^store.Store, individual, excluded: term.Term_ID, remaining: int, added_count: ^int, generalized_heads: bool, provenance: ^Closure_Provenance, rule_id: rule.Rule_ID, supports: []store.Fact_ID) -> (Class_Complement_Error_Code, store.Error_Code) {
	individual_term, individual_found := store.get_term(target, individual)
	if !individual_found do return .Store_Error, .Invalid_Fact
	if !generalized_heads && individual_term.kind == .Literal do return .None, .None
	complement, class_error, class_store_error := complement_class_for(profile, target, excluded)
	if class_error != .None do return class_error, class_store_error
	phase_error, phase_store_error := add_complement_fact(profile, target, complement, profile.terms.rdf_type, profile.terms.owl_class, remaining, added_count, generalized_heads, provenance, rule_id, supports)
	if phase_error != .None do return phase_error, phase_store_error
	phase_error, phase_store_error = add_complement_fact(profile, target, complement, profile.terms.complement_of, excluded, remaining, added_count, generalized_heads, provenance, rule_id, supports)
	if phase_error != .None do return phase_error, phase_store_error
	return add_complement_fact(profile, target, individual, profile.terms.rdf_type, complement, remaining, added_count, generalized_heads, provenance, rule_id, supports)
}

@(private) emit_disjoint_class_complements :: proc(profile: ^Profile, target: ^store.Store, max_list_items, remaining: int, added_count: ^int, generalized_heads: bool, provenance: ^Closure_Provenance) -> (Class_Complement_Error_Code, List_Error_Code, store.Error_Code) {
	list: List
	init_list(&list)
	defer destroy_list(&list)
	fact_limit := store.fact_count(target)
	for axiom_index in 0..<fact_limit {
		axiom_id, axiom, _, found := store.fact_at(target, axiom_index)
		if !found do return .Store_Error, .None, .Invalid_Fact
		if axiom.predicate == profile.terms.disjoint_with {
			for type_index in 0..<fact_limit {
				type_id, type_fact, _, type_found := store.fact_at(target, type_index)
				if !type_found do return .Store_Error, .None, .Invalid_Fact
				if type_fact.predicate != profile.terms.rdf_type do continue
				if type_fact.object == axiom.subject {
					error, store_error := emit_complement_witness(profile, target, type_fact.subject, axiom.object, remaining, added_count, generalized_heads, provenance, OWL_RDF_DISJOINT_CLASS_COMPLEMENT, []store.Fact_ID{axiom_id, type_id})
					if error != .None do return error, .None, store_error
				}
				if type_fact.object == axiom.object {
					error, store_error := emit_complement_witness(profile, target, type_fact.subject, axiom.subject, remaining, added_count, generalized_heads, provenance, OWL_RDF_DISJOINT_CLASS_COMPLEMENT, []store.Fact_ID{axiom_id, type_id})
					if error != .None do return error, .None, store_error
				}
			}
			continue
		}
		if axiom.predicate != profile.terms.rdf_type || axiom.object != profile.terms.all_disjoint_classes do continue
		for members_index in 0..<fact_limit {
			members_id, members, _, members_found := store.fact_at(target, members_index)
			if !members_found do return .Store_Error, .None, .Invalid_Fact
			if members.subject != axiom.subject || members.predicate != profile.terms.members do continue
			if list_error := read_list(profile, target, members.object, &list, {max_items = max_list_items, generalized_heads = generalized_heads}); list_error != .None do return .List_Error, list_error, .None
			for type_index in 0..<fact_limit {
				type_id, type_fact, _, type_found := store.fact_at(target, type_index)
				if !type_found do return .Store_Error, .None, .Invalid_Fact
				if type_fact.predicate != profile.terms.rdf_type do continue
				for member_index in 0..<list_count(&list) {
					member, member_found := list_item_at(&list, member_index)
					if !member_found do return .Store_Error, .None, .Invalid_Fact
					if type_fact.object != member do continue
					for other_index in 0..<list_count(&list) {
						if other_index == member_index do continue
						excluded, excluded_found := list_item_at(&list, other_index)
						if !excluded_found do return .Store_Error, .None, .Invalid_Fact
						error, store_error := emit_complement_witness(profile, target, type_fact.subject, excluded, remaining, added_count, generalized_heads, provenance, OWL_RDF_DISJOINT_CLASS_COMPLEMENT, []store.Fact_ID{axiom_id, members_id, type_id})
						if error != .None do return error, .None, store_error
					}
				}
			}
		}
	}
	return .None, .None, .None
}

@(private) emit_max_qualified_cardinality_complements :: proc(profile: ^Profile, target: ^store.Store, remaining: int, added_count: ^int, generalized_heads: bool, provenance: ^Closure_Provenance) -> (Class_Complement_Error_Code, store.Error_Code) {
	fact_limit := store.fact_count(target)
	for restriction_index in 0..<fact_limit {
		restriction_id, restriction, _, restriction_found := store.fact_at(target, restriction_index)
		if !restriction_found do return .Store_Error, .Invalid_Fact
		if restriction.predicate != profile.terms.max_qualified_cardinality || restriction.object != profile.terms.one_cardinality do continue
		for property_index in 0..<fact_limit {
			on_property_id, on_property, _, property_found := store.fact_at(target, property_index)
			if !property_found do return .Store_Error, .Invalid_Fact
			if on_property.subject != restriction.subject || on_property.predicate != profile.terms.on_property do continue
			for class_index in 0..<fact_limit {
				on_class_id, on_class, _, class_found := store.fact_at(target, class_index)
				if !class_found do return .Store_Error, .Invalid_Fact
				if on_class.subject != restriction.subject || on_class.predicate != profile.terms.on_class do continue
				for type_index in 0..<fact_limit {
					restriction_type_id, restriction_type, _, type_found := store.fact_at(target, type_index)
					if !type_found do return .Store_Error, .Invalid_Fact
					if restriction_type.predicate != profile.terms.rdf_type || restriction_type.object != restriction.subject do continue
					for known_index in 0..<fact_limit {
						known_id, known, _, known_found := store.fact_at(target, known_index)
						if !known_found do return .Store_Error, .Invalid_Fact
						if known.subject != restriction_type.subject || known.predicate != on_property.object do continue
						if store.id_for_fact(target, {subject = known.object, predicate = profile.terms.rdf_type, object = on_class.object}) == store.INVALID_FACT_ID do continue
						for other_index in 0..<fact_limit {
							other_id, other, _, other_found := store.fact_at(target, other_index)
							if !other_found do return .Store_Error, .Invalid_Fact
							if other.subject != restriction_type.subject || other.predicate != on_property.object do continue
							difference_id := store.id_for_fact(target, {subject = known.object, predicate = profile.terms.different_from, object = other.object})
							if difference_id == store.INVALID_FACT_ID do continue
							error, store_error := emit_complement_witness(profile, target, other.object, on_class.object, remaining, added_count, generalized_heads, provenance, OWL_RDF_MAX_QUALIFIED_CARDINALITY_COMPLEMENT, []store.Fact_ID{restriction_id, on_property_id, on_class_id, restriction_type_id, known_id, other_id, difference_id})
							if error != .None do return error, store_error
						}
					}
				}
			}
		}
	}
	return .None, .None
}
