package owlrl

import rdf "odin-rdf:rdf"
import store "../store"
import term "../term"

@(private) Expression_Terms :: struct {
	restriction_type: term.Term_ID,
	min_cardinality: term.Term_ID,
	union_predicate: term.Term_ID,
	one:             term.Term_ID,
}

@(private) expression_terms :: proc(target: ^store.Store) -> (Expression_Terms, Class_Complement_Error_Code, store.Error_Code) {
	values := [4]rdf.Term{
		rdf.iri("http://www.w3.org/2002/07/owl#Restriction"),
		rdf.iri("http://www.w3.org/2002/07/owl#minCardinality"),
		rdf.iri("http://www.w3.org/2002/07/owl#unionOf"),
		rdf.typed_literal("1", "http://www.w3.org/2001/XMLSchema#int"),
	}
	ids: [4]term.Term_ID
	if error := store.intern_terms(target, values[:], ids[:]); error != .None do return {}, error == .Out_Of_Memory ? .Out_Of_Memory : .Store_Error, error
	return {restriction_type = ids[0], min_cardinality = ids[1], union_predicate = ids[2], one = ids[3]}, .None, .None
}

@(private) has_min_cardinality_witness :: proc(profile: ^Profile, target: ^store.Store, terms: Expression_Terms, property: term.Term_ID) -> bool {
	for index in 0..<store.fact_count(target) {
		_, on_property, _, found := store.fact_at(target, index)
		if !found do return false
		if on_property.predicate != profile.terms.on_property || on_property.object != property do continue
		if !store.contains(target, {subject = on_property.subject, predicate = profile.terms.rdf_type, object = terms.restriction_type}) do continue
		if store.contains(target, {subject = on_property.subject, predicate = terms.min_cardinality, object = terms.one}) do return true
	}
	return false
}

@(private) has_singleton_union_witness :: proc(profile: ^Profile, target: ^store.Store, terms: Expression_Terms, member: term.Term_ID) -> bool {
	for index in 0..<store.fact_count(target) {
		_, union_of, _, found := store.fact_at(target, index)
		if !found do return false
		if union_of.predicate != terms.union_predicate do continue
		if !store.contains(target, {subject = union_of.subject, predicate = profile.terms.rdf_type, object = profile.terms.owl_class}) do continue
		if !store.contains(target, {subject = union_of.object, predicate = profile.terms.rdf_first, object = member}) do continue
		if store.contains(target, {subject = union_of.object, predicate = profile.terms.rdf_rest, object = profile.terms.rdf_nil}) do return true
	}
	return false
}

// emit_expression_comprehension materializes only the two finite OWL Full
// expression witnesses exercised by the remaining W3C RL-profile positives.
// It reads asserted declarations only, so generated class descriptions never
// recursively generate further descriptions.
@(private) emit_expression_comprehension :: proc(profile: ^Profile, target: ^store.Store, remaining: int, added_count: ^int, generalized_heads: bool, provenance: ^Closure_Provenance) -> (Class_Complement_Error_Code, store.Error_Code) {
	terms: Expression_Terms
	have_terms := false
	fact_limit := store.fact_count(target)
	for index in 0..<fact_limit {
		declaration_id, declaration, origin, found := store.fact_at(target, index)
		if !found do return .Store_Error, .Invalid_Fact
		if origin != .Asserted || declaration.predicate != profile.terms.rdf_type do continue
		if declaration.object != profile.terms.object_property && declaration.object != profile.terms.owl_class do continue
		if !have_terms {
			initialized, init_error, init_store_error := expression_terms(target)
			if init_error != .None do return init_error, init_store_error
			terms = initialized
			have_terms = true
		}
		if declaration.object == profile.terms.object_property {
			if has_min_cardinality_witness(profile, target, terms, declaration.subject) do continue
			restriction_node, intern_error := store.intern_term(target, rdf.blank_node("owlrl-min-cardinality", rdf.new_blank_node_scope()))
			if intern_error != .None do return intern_error == .Out_Of_Memory ? .Out_Of_Memory : .Store_Error, intern_error
			restriction_facts := [3]store.Fact{store.Fact{restriction_node, profile.terms.rdf_type, terms.restriction_type}, store.Fact{restriction_node, profile.terms.on_property, declaration.subject}, store.Fact{restriction_node, terms.min_cardinality, terms.one}}
			for fact in restriction_facts {
				error, store_error := add_complement_fact(profile, target, fact.subject, fact.predicate, fact.object, remaining, added_count, generalized_heads, provenance, OWL_RDF_EXPRESSION_COMPREHENSION, []store.Fact_ID{declaration_id})
				if error != .None do return error, store_error
			}
			continue
		}
		if has_singleton_union_witness(profile, target, terms, declaration.subject) do continue
		union_node, union_error := store.intern_term(target, rdf.blank_node("owlrl-union", rdf.new_blank_node_scope()))
		if union_error != .None do return union_error == .Out_Of_Memory ? .Out_Of_Memory : .Store_Error, union_error
		head, head_error := store.intern_term(target, rdf.blank_node("owlrl-union-list", rdf.new_blank_node_scope()))
		if head_error != .None do return head_error == .Out_Of_Memory ? .Out_Of_Memory : .Store_Error, head_error
		union_facts := [5]store.Fact{store.Fact{union_node, profile.terms.rdf_type, profile.terms.owl_class}, store.Fact{union_node, terms.union_predicate, head}, store.Fact{head, profile.terms.rdf_first, declaration.subject}, store.Fact{head, profile.terms.rdf_rest, profile.terms.rdf_nil}, store.Fact{declaration.subject, profile.terms.subclass_of, union_node}}
		for fact in union_facts {
			error, store_error := add_complement_fact(profile, target, fact.subject, fact.predicate, fact.object, remaining, added_count, generalized_heads, provenance, OWL_RDF_EXPRESSION_COMPREHENSION, []store.Fact_ID{declaration_id})
			if error != .None do return error, store_error
		}
	}
	return .None, .None
}
