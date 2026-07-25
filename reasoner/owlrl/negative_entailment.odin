package owlrl

import rdf "odin-rdf:rdf"
import rdfs "../rdfs"
import store "../store"
import term "../term"

// Negative_Entailment_Status never infers a negative result from an absent
// triple. Countermodel means that the supplied, deliberately narrow witness
// has been checked against the supported semantic fragment; Unsupported means
// the caller must use a broader model finder.
Negative_Entailment_Status :: enum {
	Countermodel,
	Unsupported,
	Invalid_Certificate,
}

Range_Countermodel_Certificate :: struct {
	property:             rdf.Term,
	premise_range:        rdf.Term,
	nonconclusion_range:  rdf.Term,
	witness_value:        rdf.Term,
}

Negative_Entailment_Result :: struct { status: Negative_Entailment_Status }

Class_Equivalence_Countermodel_Certificate :: struct {
	left:  rdf.Term,
	right: rdf.Term,
}

Property_Chain_Countermodel_Certificate :: struct {
	property:       rdf.Term,
	second_property: rdf.Term,
	left:           rdf.Term,
	middle:         rdf.Term,
	right:          rdf.Term,
}

Has_Key_Countermodel_Certificate :: struct {
	class:       rdf.Term,
	property:    rdf.Term,
	keyed_left:  rdf.Term,
	keyed_right: rdf.Term,
	outsider:    rdf.Term,
	key_value:   rdf.Term,
}

Has_Key_Consistency_Certificate :: struct {
	class:        rdf.Term,
	property:     rdf.Term,
	individual:   rdf.Term,
	first_value:  rdf.Term,
	second_value: rdf.Term,
}

Consistency_Model_Status :: enum {
	Model,
	Unsupported,
	Invalid_Certificate,
}

Consistency_Model_Result :: struct { status: Consistency_Model_Status }

Inconsistency_Proof_Status :: enum {
	Contradiction,
	Unsupported,
	Invalid_Certificate,
}

Inconsistency_Proof_Result :: struct { status: Inconsistency_Proof_Status }

@(private) certificate_term_id :: proc(target: ^store.Store, value: rdf.Term) -> term.Term_ID {
	if rdf.validate_term_structure(value) != .None do return term.INVALID_TERM_ID
	return store.id_for_term(target, value)
}

// verify_range_countermodel proves one finite RDFS/OWL datatype countermodel.
// It accepts only a normalized premise with one asserted rdfs:range axiom and
// an optional matching owl:DatatypeProperty declaration. Its model interprets
// the property as containing the supplied literal value. The certificate is
// valid precisely when that value is in the asserted range and outside the
// proposed nonconclusion range.
verify_range_countermodel :: proc(target: ^store.Store, certificate: Range_Countermodel_Certificate) -> Negative_Entailment_Result {
	property := certificate_term_id(target, certificate.property)
	premise_range := certificate_term_id(target, certificate.premise_range)
	nonconclusion_range := certificate_term_id(target, certificate.nonconclusion_range)
	if property == term.INVALID_TERM_ID || premise_range == term.INVALID_TERM_ID do return {.Invalid_Certificate}
	if certificate.property.kind != .IRI || certificate.premise_range.kind != .IRI || certificate.nonconclusion_range.kind != .IRI || certificate.witness_value.kind != .Literal do return {.Invalid_Certificate}
	if rdf.owl_rl_literal_value_membership(certificate.witness_value, certificate.premise_range.value) != .Yes do return {.Invalid_Certificate}
	if rdf.owl_rl_literal_value_membership(certificate.witness_value, certificate.nonconclusion_range.value) != .No do return {.Invalid_Certificate}

	range := store.id_for_term(target, rdf.iri(rdfs.RDFS_RANGE_IRI))
	datatype_property := store.id_for_term(target, rdf.iri(OWL_DATATYPE_PROPERTY))
	if range == term.INVALID_TERM_ID || datatype_property == term.INVALID_TERM_ID do return {.Unsupported}
	if !store.contains(target, {subject = property, predicate = range, object = premise_range}) do return {.Invalid_Certificate}
	if nonconclusion_range != term.INVALID_TERM_ID && store.contains(target, {subject = property, predicate = range, object = nonconclusion_range}) do return {.Invalid_Certificate}

	for index in 0..<store.fact_count(target) {
		_, fact, origin, found := store.fact_at(target, index)
		if !found || origin != .Asserted do return {.Unsupported}
		if fact.subject == property && fact.predicate == range && fact.object == premise_range do continue
		if fact.subject == property && fact.predicate == store.id_for_term(target, rdf.iri(rdfs.RDF_TYPE)) && fact.object == datatype_property do continue
		return {.Unsupported}
	}
	// The model extension contains (property, witness); membership was checked above.
	return {.Countermodel}
}

// verify_class_equivalence_countermodel checks the finite empty-extension
// model for a normalized class-equivalence premise. It keeps the two class
// resources distinct while assigning them the same empty class extension,
// which satisfies owl:equivalentClass but falsifies owl:sameAs.
verify_class_equivalence_countermodel :: proc(target: ^store.Store, certificate: Class_Equivalence_Countermodel_Certificate) -> Negative_Entailment_Result {
	left := certificate_term_id(target, certificate.left)
	right := certificate_term_id(target, certificate.right)
	if left == term.INVALID_TERM_ID || right == term.INVALID_TERM_ID || certificate.left.kind != .IRI || certificate.right.kind != .IRI || left == right do return {.Invalid_Certificate}
	equivalent_class := store.id_for_term(target, rdf.iri(OWL_EQUIVALENT_CLASS))
	same_as := store.id_for_term(target, rdf.iri(OWL_SAME_AS))
	rdf_type := store.id_for_term(target, rdf.iri(rdfs.RDF_TYPE))
	owl_class := store.id_for_term(target, rdf.iri(OWL_CLASS))
	if equivalent_class == term.INVALID_TERM_ID || rdf_type == term.INVALID_TERM_ID || owl_class == term.INVALID_TERM_ID do return {.Unsupported}
	if !store.contains(target, {subject = left, predicate = equivalent_class, object = right}) do return {.Invalid_Certificate}
	if same_as != term.INVALID_TERM_ID && store.contains(target, {subject = left, predicate = same_as, object = right}) do return {.Invalid_Certificate}
	for index in 0..<store.fact_count(target) {
		_, fact, origin, found := store.fact_at(target, index)
		if !found || origin != .Asserted do return {.Unsupported}
		if fact.subject == left && fact.predicate == equivalent_class && fact.object == right do continue
		if (fact.subject == left || fact.subject == right) && fact.predicate == rdf_type && fact.object == owl_class do continue
		return {.Unsupported}
	}
	return {.Countermodel}
}

// verify_property_chain_countermodel checks a finite witness for the shape
// P o Q subPropertyOf P. It adds P(left,middle) and P(middle,right) to the
// model while deliberately giving Q no edge out of middle, so the chain axiom
// remains satisfied but P(left,right) is false and P is not transitive.
verify_property_chain_countermodel :: proc(target: ^store.Store, certificate: Property_Chain_Countermodel_Certificate) -> Negative_Entailment_Result {
	property := certificate_term_id(target, certificate.property)
	second_property := certificate_term_id(target, certificate.second_property)
	if property == term.INVALID_TERM_ID || second_property == term.INVALID_TERM_ID || certificate.property.kind != .IRI || certificate.second_property.kind != .IRI do return {.Invalid_Certificate}
	model_nodes := [3]rdf.Term{certificate.left, certificate.middle, certificate.right}
	for value in model_nodes {
		if value.kind != .IRI || rdf.validate_term_structure(value) != .None do return {.Invalid_Certificate}
	}
	if certificate.left.value == certificate.middle.value || certificate.middle.value == certificate.right.value || certificate.left.value == certificate.right.value do return {.Invalid_Certificate}
	chain := store.id_for_term(target, rdf.iri(OWL_PROPERTY_CHAIN_AXIOM))
	first := store.id_for_term(target, rdf.iri(RDF_FIRST))
	rest := store.id_for_term(target, rdf.iri(RDF_REST))
	nil := store.id_for_term(target, rdf.iri(RDF_NIL))
	transitive := store.id_for_term(target, rdf.iri(OWL_TRANSITIVE_PROPERTY))
	rdf_type := store.id_for_term(target, rdf.iri(rdfs.RDF_TYPE))
	object_property := store.id_for_term(target, rdf.iri(OWL_OBJECT_PROPERTY))
	if chain == term.INVALID_TERM_ID || first == term.INVALID_TERM_ID || rest == term.INVALID_TERM_ID || nil == term.INVALID_TERM_ID do return {.Unsupported}
	if transitive != term.INVALID_TERM_ID && store.contains(target, {subject = property, predicate = rdf_type, object = transitive}) do return {.Invalid_Certificate}

	head := term.INVALID_TERM_ID
	for index in 0..<store.fact_count(target) {
		_, fact, _, found := store.fact_at(target, index)
		if !found do return {.Unsupported}
		if fact.subject == property && fact.predicate == chain { head = fact.object; break }
	}
	if head == term.INVALID_TERM_ID do return {.Invalid_Certificate}
	tail := term.INVALID_TERM_ID
	for index in 0..<store.fact_count(target) {
		_, fact, origin, found := store.fact_at(target, index)
		if !found || origin != .Asserted do return {.Unsupported}
		if fact.subject == property && fact.predicate == chain && fact.object == head do continue
		if fact.subject == head && fact.predicate == first && fact.object == property do continue
		if fact.subject == head && fact.predicate == rest { tail = fact.object; continue }
		if tail != term.INVALID_TERM_ID && fact.subject == tail && fact.predicate == first && fact.object == second_property do continue
		if tail != term.INVALID_TERM_ID && fact.subject == tail && fact.predicate == rest && fact.object == nil do continue
		if rdf_type != term.INVALID_TERM_ID && object_property != term.INVALID_TERM_ID && (fact.subject == property || fact.subject == second_property) && fact.predicate == rdf_type && fact.object == object_property do continue
		if fact.predicate == second_property {
			middle_id := store.id_for_term(target, certificate.middle)
			if middle_id != term.INVALID_TERM_ID && fact.subject == middle_id do return {.Invalid_Certificate}
			continue
		}
		return {.Unsupported}
	}
	if tail == term.INVALID_TERM_ID || !store.contains(target, {subject = head, predicate = first, object = property}) || !store.contains(target, {subject = head, predicate = rest, object = tail}) || !store.contains(target, {subject = tail, predicate = first, object = second_property}) || !store.contains(target, {subject = tail, predicate = rest, object = nil}) do return {.Invalid_Certificate}
	return {.Countermodel}
}

// verify_has_key_countermodel checks the localized-key shape with one
// data-property key. Its finite model identifies the two typed key holders
// while keeping the untyped holder distinct. Thus the key axiom is satisfied,
// but owl:sameAs between a class member and that outsider is false.
verify_has_key_countermodel :: proc(target: ^store.Store, certificate: Has_Key_Countermodel_Certificate) -> Negative_Entailment_Result {
	class := certificate_term_id(target, certificate.class)
	property := certificate_term_id(target, certificate.property)
	keyed_left := certificate_term_id(target, certificate.keyed_left)
	keyed_right := certificate_term_id(target, certificate.keyed_right)
	outsider := certificate_term_id(target, certificate.outsider)
	key_value := certificate_term_id(target, certificate.key_value)
	if class == term.INVALID_TERM_ID || property == term.INVALID_TERM_ID || keyed_left == term.INVALID_TERM_ID || keyed_right == term.INVALID_TERM_ID || outsider == term.INVALID_TERM_ID || key_value == term.INVALID_TERM_ID do return {.Invalid_Certificate}
	if certificate.class.kind != .IRI || certificate.property.kind != .IRI || certificate.keyed_left.kind != .IRI || certificate.keyed_right.kind != .IRI || certificate.outsider.kind != .IRI || certificate.key_value.kind != .Literal do return {.Invalid_Certificate}
	if keyed_left == keyed_right || keyed_left == outsider || keyed_right == outsider do return {.Invalid_Certificate}

	has_key := store.id_for_term(target, rdf.iri(OWL_HAS_KEY))
	first := store.id_for_term(target, rdf.iri(RDF_FIRST))
	rest := store.id_for_term(target, rdf.iri(RDF_REST))
	nil := store.id_for_term(target, rdf.iri(RDF_NIL))
	rdf_type := store.id_for_term(target, rdf.iri(rdfs.RDF_TYPE))
	same_as := store.id_for_term(target, rdf.iri(OWL_SAME_AS))
	if has_key == term.INVALID_TERM_ID || first == term.INVALID_TERM_ID || rest == term.INVALID_TERM_ID || nil == term.INVALID_TERM_ID || rdf_type == term.INVALID_TERM_ID do return {.Unsupported}
	if same_as != term.INVALID_TERM_ID && store.contains(target, {subject = keyed_left, predicate = same_as, object = outsider}) do return {.Invalid_Certificate}

	head := term.INVALID_TERM_ID
	for index in 0..<store.fact_count(target) {
		_, fact, _, found := store.fact_at(target, index)
		if !found do return {.Unsupported}
		if fact.subject == class && fact.predicate == has_key { head = fact.object; break }
	}
	if head == term.INVALID_TERM_ID do return {.Invalid_Certificate}

	for index in 0..<store.fact_count(target) {
		_, fact, origin, found := store.fact_at(target, index)
		if !found || origin != .Asserted do return {.Unsupported}
		if fact.subject == class && fact.predicate == has_key && fact.object == head do continue
		if fact.subject == head && fact.predicate == first && fact.object == property do continue
		if fact.subject == head && fact.predicate == rest && fact.object == nil do continue
		if (fact.subject == keyed_left || fact.subject == keyed_right || fact.subject == outsider) && fact.predicate == property && fact.object == key_value do continue
		if (fact.subject == keyed_left || fact.subject == keyed_right) && fact.predicate == rdf_type && fact.object == class do continue
		if fact.subject == outsider && fact.predicate == rdf_type && fact.object == class do return {.Invalid_Certificate}
		return {.Unsupported}
	}
	if !store.contains(target, {subject = class, predicate = has_key, object = head}) || !store.contains(target, {subject = head, predicate = first, object = property}) || !store.contains(target, {subject = head, predicate = rest, object = nil}) do return {.Invalid_Certificate}

	// Interpret keyed_left and keyed_right as one domain element in class, and
	// outsider as a second element outside it; every named resource has the one
	// supplied key value. The localized key therefore holds and the requested
	// member/outsider equality remains false.
	return {.Countermodel}
}

// verify_has_key_consistency_model checks a finite one-individual model for a
// localized key with two distinct data values. The key is vacuously satisfied
// for its one class member, so it does not make the listed property functional.
verify_has_key_consistency_model :: proc(target: ^store.Store, certificate: Has_Key_Consistency_Certificate) -> Consistency_Model_Result {
	class := certificate_term_id(target, certificate.class)
	property := certificate_term_id(target, certificate.property)
	individual := certificate_term_id(target, certificate.individual)
	first_value := certificate_term_id(target, certificate.first_value)
	second_value := certificate_term_id(target, certificate.second_value)
	if class == term.INVALID_TERM_ID || property == term.INVALID_TERM_ID || individual == term.INVALID_TERM_ID || first_value == term.INVALID_TERM_ID || second_value == term.INVALID_TERM_ID do return {.Invalid_Certificate}
	if certificate.class.kind != .IRI || certificate.property.kind != .IRI || certificate.individual.kind != .IRI || certificate.first_value.kind != .Literal || certificate.second_value.kind != .Literal || first_value == second_value do return {.Invalid_Certificate}

	has_key := store.id_for_term(target, rdf.iri(OWL_HAS_KEY))
	first := store.id_for_term(target, rdf.iri(RDF_FIRST))
	rest := store.id_for_term(target, rdf.iri(RDF_REST))
	nil := store.id_for_term(target, rdf.iri(RDF_NIL))
	rdf_type := store.id_for_term(target, rdf.iri(rdfs.RDF_TYPE))
	functional_property := store.id_for_term(target, rdf.iri(OWL_FUNCTIONAL_PROPERTY))
	if has_key == term.INVALID_TERM_ID || first == term.INVALID_TERM_ID || rest == term.INVALID_TERM_ID || nil == term.INVALID_TERM_ID || rdf_type == term.INVALID_TERM_ID do return {.Unsupported}
	if functional_property != term.INVALID_TERM_ID && store.contains(target, {subject = property, predicate = rdf_type, object = functional_property}) do return {.Invalid_Certificate}

	head := term.INVALID_TERM_ID
	for index in 0..<store.fact_count(target) {
		_, fact, _, found := store.fact_at(target, index)
		if !found do return {.Unsupported}
		if fact.subject == class && fact.predicate == has_key { head = fact.object; break }
	}
	if head == term.INVALID_TERM_ID do return {.Invalid_Certificate}

	for index in 0..<store.fact_count(target) {
		_, fact, origin, found := store.fact_at(target, index)
		if !found || origin != .Asserted do return {.Unsupported}
		if fact.subject == class && fact.predicate == has_key && fact.object == head do continue
		if fact.subject == head && fact.predicate == first && fact.object == property do continue
		if fact.subject == head && fact.predicate == rest && fact.object == nil do continue
		if fact.subject == individual && fact.predicate == property && (fact.object == first_value || fact.object == second_value) do continue
		if fact.subject == individual && fact.predicate == rdf_type && fact.object == class do continue
		return {.Unsupported}
	}
	if !store.contains(target, {subject = class, predicate = has_key, object = head}) || !store.contains(target, {subject = head, predicate = first, object = property}) || !store.contains(target, {subject = head, predicate = rest, object = nil}) || !store.contains(target, {subject = individual, predicate = property, object = first_value}) || !store.contains(target, {subject = individual, predicate = property, object = second_value}) || !store.contains(target, {subject = individual, predicate = rdf_type, object = class}) do return {.Invalid_Certificate}

	// Interpret individual as the sole class member and retain both distinct
	// literals in property. The key condition only compares pairs of class
	// members, so this model satisfies it without functionalizing property.
	return {.Model}
}

@(private) find_singleton_intersection :: proc(target: ^store.Store, intersection, first, rest, nil, named_class: term.Term_ID) -> (class, head: term.Term_ID, found: bool) {
	for index in 0..<store.fact_count(target) {
		_, fact, _, fact_found := store.fact_at(target, index)
		if !fact_found do return term.INVALID_TERM_ID, term.INVALID_TERM_ID, false
		if fact.predicate != intersection do continue
		if store.contains(target, {subject = fact.object, predicate = first, object = named_class}) && store.contains(target, {subject = fact.object, predicate = rest, object = nil}) do return fact.subject, fact.object, true
	}
	return term.INVALID_TERM_ID, term.INVALID_TERM_ID, false
}

// verify_intersection_type_structure_sharing_model recognizes the normalized
// I5.26-001 shape. One resource is both the intersection class and the object
// of a type assertion. Interpret it and its singleton member as {d}; assign
// the other intersection member an empty extension. Every displayed axiom is
// then true in a finite model.
verify_intersection_type_structure_sharing_model :: proc(target: ^store.Store, named_class, other_class: rdf.Term) -> Consistency_Model_Result {
	named := certificate_term_id(target, named_class)
	other := certificate_term_id(target, other_class)
	if named == term.INVALID_TERM_ID || other == term.INVALID_TERM_ID || named_class.kind != .IRI || other_class.kind != .IRI || named == other do return {.Invalid_Certificate}
	intersection := store.id_for_term(target, rdf.iri("http://www.w3.org/2002/07/owl#intersectionOf"))
	first := store.id_for_term(target, rdf.iri(RDF_FIRST))
	rest := store.id_for_term(target, rdf.iri(RDF_REST))
	nil := store.id_for_term(target, rdf.iri(RDF_NIL))
	rdf_type := store.id_for_term(target, rdf.iri(rdfs.RDF_TYPE))
	if intersection == term.INVALID_TERM_ID || first == term.INVALID_TERM_ID || rest == term.INVALID_TERM_ID || nil == term.INVALID_TERM_ID || rdf_type == term.INVALID_TERM_ID do return {.Unsupported}
	shared, head, shared_found := find_singleton_intersection(target, intersection, first, rest, nil, named)
	if !shared_found do return {.Invalid_Certificate}
	instance, expr, expr_head, tail := term.INVALID_TERM_ID, term.INVALID_TERM_ID, term.INVALID_TERM_ID, term.INVALID_TERM_ID
	for index in 0..<store.fact_count(target) {
		_, fact, origin, found := store.fact_at(target, index)
		if !found || origin != .Asserted do return {.Unsupported}
		if fact.subject == shared && fact.predicate == intersection && fact.object == head do continue
		if fact.subject == head && fact.predicate == first && fact.object == named do continue
		if fact.subject == head && fact.predicate == rest && fact.object == nil do continue
		if fact.predicate == rdf_type && fact.object == shared { instance = fact.subject; continue }
		if fact.predicate == intersection && fact.subject != shared {
			expr, expr_head = fact.subject, fact.object
			continue
		}
		if fact.subject == expr_head && fact.predicate == first && fact.object == other do continue
		if fact.subject == expr_head && fact.predicate == rest { tail = fact.object; continue }
		if fact.subject == tail && fact.predicate == first && fact.object == shared do continue
		if fact.subject == tail && fact.predicate == rest && fact.object == nil do continue
		return {.Unsupported}
	}
	if instance == term.INVALID_TERM_ID || expr == term.INVALID_TERM_ID || expr_head == term.INVALID_TERM_ID || tail == term.INVALID_TERM_ID || instance == shared || expr == shared || !store.contains(target, {subject = expr_head, predicate = first, object = other}) || !store.contains(target, {subject = expr_head, predicate = rest, object = tail}) || !store.contains(target, {subject = tail, predicate = first, object = shared}) || !store.contains(target, {subject = tail, predicate = rest, object = nil}) do return {.Invalid_Certificate}
	return {.Model}
}

// verify_equivalent_type_structure_sharing_model recognizes I5.26-002. The
// shared intersection class and its equivalent named class both denote {d};
// its typed instance denotes d, so all supplied statements have a finite
// model.
verify_equivalent_type_structure_sharing_model :: proc(target: ^store.Store, named_class, equivalent_class: rdf.Term) -> Consistency_Model_Result {
	named := certificate_term_id(target, named_class)
	equivalent := certificate_term_id(target, equivalent_class)
	if named == term.INVALID_TERM_ID || equivalent == term.INVALID_TERM_ID || named_class.kind != .IRI || equivalent_class.kind != .IRI || named == equivalent do return {.Invalid_Certificate}
	intersection := store.id_for_term(target, rdf.iri("http://www.w3.org/2002/07/owl#intersectionOf"))
	equivalent_class_id := store.id_for_term(target, rdf.iri(OWL_EQUIVALENT_CLASS))
	first := store.id_for_term(target, rdf.iri(RDF_FIRST))
	rest := store.id_for_term(target, rdf.iri(RDF_REST))
	nil := store.id_for_term(target, rdf.iri(RDF_NIL))
	rdf_type := store.id_for_term(target, rdf.iri(rdfs.RDF_TYPE))
	if intersection == term.INVALID_TERM_ID || equivalent_class_id == term.INVALID_TERM_ID || first == term.INVALID_TERM_ID || rest == term.INVALID_TERM_ID || nil == term.INVALID_TERM_ID || rdf_type == term.INVALID_TERM_ID do return {.Unsupported}
	shared, head, shared_found := find_singleton_intersection(target, intersection, first, rest, nil, named)
	if !shared_found do return {.Invalid_Certificate}
	instance := term.INVALID_TERM_ID
	for index in 0..<store.fact_count(target) {
		_, fact, origin, found := store.fact_at(target, index)
		if !found || origin != .Asserted do return {.Unsupported}
		if fact.subject == shared && fact.predicate == intersection && fact.object == head do continue
		if fact.subject == head && fact.predicate == first && fact.object == named do continue
		if fact.subject == head && fact.predicate == rest && fact.object == nil do continue
		if fact.subject == shared && fact.predicate == equivalent_class_id && fact.object == equivalent do continue
		if fact.predicate == rdf_type && fact.object == shared { instance = fact.subject; continue }
		return {.Unsupported}
	}
	if instance == term.INVALID_TERM_ID || instance == shared || !store.contains(target, {subject = shared, predicate = equivalent_class_id, object = equivalent}) do return {.Invalid_Certificate}
	return {.Model}
}

// verify_equivalent_disjoint_structure_sharing_model recognizes I5.26-005.
// Assigning every displayed class the empty extension satisfies both the
// singleton intersection, the equivalence, and the disjointness statement.
verify_equivalent_disjoint_structure_sharing_model :: proc(target: ^store.Store, named_class, disjoint_class, equivalent_class: rdf.Term) -> Consistency_Model_Result {
	named := certificate_term_id(target, named_class)
	disjoint := certificate_term_id(target, disjoint_class)
	equivalent := certificate_term_id(target, equivalent_class)
	if named == term.INVALID_TERM_ID || disjoint == term.INVALID_TERM_ID || equivalent == term.INVALID_TERM_ID || named_class.kind != .IRI || disjoint_class.kind != .IRI || equivalent_class.kind != .IRI || named == disjoint || named == equivalent || disjoint == equivalent do return {.Invalid_Certificate}
	intersection := store.id_for_term(target, rdf.iri("http://www.w3.org/2002/07/owl#intersectionOf"))
	disjoint_with := store.id_for_term(target, rdf.iri(OWL_DISJOINT_WITH))
	equivalent_class_id := store.id_for_term(target, rdf.iri(OWL_EQUIVALENT_CLASS))
	first := store.id_for_term(target, rdf.iri(RDF_FIRST))
	rest := store.id_for_term(target, rdf.iri(RDF_REST))
	nil := store.id_for_term(target, rdf.iri(RDF_NIL))
	if intersection == term.INVALID_TERM_ID || disjoint_with == term.INVALID_TERM_ID || equivalent_class_id == term.INVALID_TERM_ID || first == term.INVALID_TERM_ID || rest == term.INVALID_TERM_ID || nil == term.INVALID_TERM_ID do return {.Unsupported}
	shared, head, shared_found := find_singleton_intersection(target, intersection, first, rest, nil, named)
	if !shared_found do return {.Invalid_Certificate}
	for index in 0..<store.fact_count(target) {
		_, fact, origin, found := store.fact_at(target, index)
		if !found || origin != .Asserted do return {.Unsupported}
		if fact.subject == shared && fact.predicate == intersection && fact.object == head do continue
		if fact.subject == head && fact.predicate == first && fact.object == named do continue
		if fact.subject == head && fact.predicate == rest && fact.object == nil do continue
		if fact.subject == shared && fact.predicate == disjoint_with && fact.object == disjoint do continue
		if fact.subject == shared && fact.predicate == equivalent_class_id && fact.object == equivalent do continue
		return {.Unsupported}
	}
	if !store.contains(target, {subject = shared, predicate = disjoint_with, object = disjoint}) || !store.contains(target, {subject = shared, predicate = equivalent_class_id, object = equivalent}) do return {.Invalid_Certificate}
	return {.Model}
}

// verify_disjoint_class_edges_consistency_model accepts only asserted
// owl:disjointWith edges over resource terms. Giving every mentioned class the
// empty extension is then a finite model of every edge, including self edges;
// no absence of a conflict is used as a consistency result.
verify_disjoint_class_edges_consistency_model :: proc(target: ^store.Store) -> Consistency_Model_Result {
	disjoint_with := store.id_for_term(target, rdf.iri(OWL_DISJOINT_WITH))
	if disjoint_with == term.INVALID_TERM_ID do return {.Unsupported}
	edge_count := 0
	for index in 0..<store.fact_count(target) {
		_, fact, origin, found := store.fact_at(target, index)
		if !found || origin != .Asserted do return {.Unsupported}
		if fact.predicate != disjoint_with do return {.Unsupported}
		subject, subject_found := store.get_term(target, fact.subject)
		object, object_found := store.get_term(target, fact.object)
		if !subject_found || !object_found || (subject.kind != .IRI && subject.kind != .Blank_Node) || (object.kind != .IRI && object.kind != .Blank_Node) do return {.Invalid_Certificate}
		edge_count += 1
	}
	if edge_count == 0 do return {.Invalid_Certificate}
	return {.Model}
}

@(private) semantic_member_contains :: proc(members: []term.Term_ID, value: term.Term_ID) -> bool {
	for member in members do if member == value do return true
	return false
}

@(private) semantic_member_add :: proc(members: ^[dynamic]term.Term_ID, value: term.Term_ID) -> (added, ok: bool) {
	if semantic_member_contains(members^[:], value) do return false, true
	_, append_error := append(members, value)
	if append_error != nil do return false, false
	return true, true
}

@(private) semantic_read_list :: proc(target: ^store.Store, head, first, rest, nil: term.Term_ID, items: ^[dynamic]term.Term_ID) -> (valid, memory_ok: bool) {
	current := head
	for _ in 0..<store.fact_count(target) + 1 {
		if current == nil do return true, true
		item, next := term.INVALID_TERM_ID, term.INVALID_TERM_ID
		for index in 0..<store.fact_count(target) {
			_, fact, _, found := store.fact_at(target, index)
			if !found do return false, true
			if fact.subject != current do continue
			if fact.predicate == first {
				if item != term.INVALID_TERM_ID do return false, true
				item = fact.object
			} else if fact.predicate == rest {
				if next != term.INVALID_TERM_ID do return false, true
				next = fact.object
			}
		}
		if item == term.INVALID_TERM_ID || next == term.INVALID_TERM_ID do return false, true
		_, append_error := append(items, item)
		if append_error != .None do return false, false
		current = next
	}
	return false, true
}

// verify_class_expression_contradiction proves the narrow class-expression
// fragment used by the three W3C description-logic cases. Starting from an
// asserted instance of seed_class, it follows equivalentClass, intersectionOf,
// and subClassOf membership consequences. A resource that reaches both sides
// of an owl:complementOf pair is an explicit semantic contradiction.
verify_class_expression_contradiction :: proc(target: ^store.Store, seed_class: rdf.Term) -> Inconsistency_Proof_Result {
	seed := certificate_term_id(target, seed_class)
	if seed == term.INVALID_TERM_ID || seed_class.kind != .IRI do return {.Invalid_Certificate}
	equivalent := store.id_for_term(target, rdf.iri(OWL_EQUIVALENT_CLASS))
	intersection := store.id_for_term(target, rdf.iri("http://www.w3.org/2002/07/owl#intersectionOf"))
	subclass := store.id_for_term(target, rdf.iri(rdfs.RDFS_SUBCLASS))
	complement := store.id_for_term(target, rdf.iri("http://www.w3.org/2002/07/owl#complementOf"))
	rdf_type := store.id_for_term(target, rdf.iri(rdfs.RDF_TYPE))
	first := store.id_for_term(target, rdf.iri(RDF_FIRST))
	rest := store.id_for_term(target, rdf.iri(RDF_REST))
	nil := store.id_for_term(target, rdf.iri(RDF_NIL))
	if equivalent == term.INVALID_TERM_ID || subclass == term.INVALID_TERM_ID || complement == term.INVALID_TERM_ID || rdf_type == term.INVALID_TERM_ID do return {.Unsupported}

	members := make([dynamic]term.Term_ID)
	defer delete(members)
	seeded := false
	for index in 0..<store.fact_count(target) {
		_, fact, origin, found := store.fact_at(target, index)
		if !found || origin != .Asserted do return {.Unsupported}
		if fact.predicate == equivalent || fact.predicate == intersection || fact.predicate == subclass || fact.predicate == complement || fact.predicate == first || fact.predicate == rest do continue
		if fact.predicate == rdf_type && fact.object == seed { seeded = true; continue }
		return {.Unsupported}
	}
	if !seeded do return {.Invalid_Certificate}
	_, added := semantic_member_add(&members, seed)
	if !added do return {.Unsupported}

	for changed := true; changed; {
		changed = false
		for index in 0..<store.fact_count(target) {
			_, fact, _, found := store.fact_at(target, index)
			if !found do return {.Unsupported}
			if fact.predicate == equivalent {
				if semantic_member_contains(members[:], fact.subject) {
					member_added, ok := semantic_member_add(&members, fact.object)
					if !ok do return {.Unsupported}
					changed = changed || member_added
				}
				if semantic_member_contains(members[:], fact.object) {
					member_added, ok := semantic_member_add(&members, fact.subject)
					if !ok do return {.Unsupported}
					changed = changed || member_added
				}
			} else if fact.predicate == subclass && semantic_member_contains(members[:], fact.subject) {
				member_added, ok := semantic_member_add(&members, fact.object)
				if !ok do return {.Unsupported}
				changed = changed || member_added
			} else if fact.predicate == intersection && semantic_member_contains(members[:], fact.subject) {
				if intersection == term.INVALID_TERM_ID || first == term.INVALID_TERM_ID || rest == term.INVALID_TERM_ID || nil == term.INVALID_TERM_ID do return {.Unsupported}
				list_items := make([dynamic]term.Term_ID)
				list_valid, list_memory_ok := semantic_read_list(target, fact.object, first, rest, nil, &list_items)
				if !list_memory_ok { delete(list_items); return {.Unsupported} }
				if !list_valid || len(list_items) == 0 { delete(list_items); return {.Invalid_Certificate} }
				for item in list_items {
					item_term, item_term_found := store.get_term(target, item)
					if !item_term_found || (item_term.kind != .IRI && item_term.kind != .Blank_Node) { delete(list_items); return {.Invalid_Certificate} }
					member_added, ok := semantic_member_add(&members, item)
					if !ok { delete(list_items); return {.Unsupported} }
					changed = changed || member_added
				}
				delete(list_items)
			}
		}
	}
	for index in 0..<store.fact_count(target) {
		_, fact, _, found := store.fact_at(target, index)
		if !found do return {.Unsupported}
		if fact.predicate == complement && semantic_member_contains(members[:], fact.subject) && semantic_member_contains(members[:], fact.object) do return {.Contradiction}
	}
	return {.Invalid_Certificate}
}

// verify_anonymous_individual_consistency_model accepts one object-property
// assertion from an anonymous subject to a named object. A two-element domain
// with that one property edge is an explicit finite model.
verify_anonymous_individual_consistency_model :: proc(target: ^store.Store, named_object: rdf.Term) -> Consistency_Model_Result {
	object := certificate_term_id(target, named_object)
	if object == term.INVALID_TERM_ID || named_object.kind != .IRI || store.fact_count(target) != 1 do return {.Invalid_Certificate}
	_, fact, origin, found := store.fact_at(target, 0)
	if !found || origin != .Asserted do return {.Unsupported}
	subject, subject_found := store.get_term(target, fact.subject)
	predicate, predicate_found := store.get_term(target, fact.predicate)
	if !subject_found || !predicate_found || subject.kind != .Blank_Node || predicate.kind != .IRI || fact.object != object do return {.Invalid_Certificate}
	return {.Model}
}

// verify_one_of_subclass_consistency_model checks a two-member oneOf class
// below a named superclass. Interpret the oneOf class as exactly those two
// elements and the superclass as their superset.
verify_one_of_subclass_consistency_model :: proc(target: ^store.Store, superclass, first_member, second_member: rdf.Term) -> Consistency_Model_Result {
	super := certificate_term_id(target, superclass)
	first_member_id := certificate_term_id(target, first_member)
	second_member_id := certificate_term_id(target, second_member)
	if super == term.INVALID_TERM_ID || first_member_id == term.INVALID_TERM_ID || second_member_id == term.INVALID_TERM_ID || superclass.kind != .IRI || first_member.kind != .IRI || second_member.kind != .IRI || first_member_id == second_member_id do return {.Invalid_Certificate}
	subclass := store.id_for_term(target, rdf.iri(rdfs.RDFS_SUBCLASS))
	one_of := store.id_for_term(target, rdf.iri(OWL_ONE_OF))
	first := store.id_for_term(target, rdf.iri(RDF_FIRST))
	rest := store.id_for_term(target, rdf.iri(RDF_REST))
	nil := store.id_for_term(target, rdf.iri(RDF_NIL))
	if subclass == term.INVALID_TERM_ID || one_of == term.INVALID_TERM_ID || first == term.INVALID_TERM_ID || rest == term.INVALID_TERM_ID || nil == term.INVALID_TERM_ID do return {.Unsupported}
	class, head := term.INVALID_TERM_ID, term.INVALID_TERM_ID
	for index in 0..<store.fact_count(target) {
		_, fact, _, found := store.fact_at(target, index)
		if !found do return {.Unsupported}
		if fact.predicate == one_of { class, head = fact.subject, fact.object; break }
	}
	if class == term.INVALID_TERM_ID do return {.Invalid_Certificate}
	tail := term.INVALID_TERM_ID
	for index in 0..<store.fact_count(target) {
		_, fact, origin, found := store.fact_at(target, index)
		if !found || origin != .Asserted do return {.Unsupported}
		if fact.subject == class && fact.predicate == subclass && fact.object == super do continue
		if fact.subject == class && fact.predicate == one_of && fact.object == head do continue
		if fact.subject == head && fact.predicate == first && fact.object == first_member_id do continue
		if fact.subject == head && fact.predicate == rest { tail = fact.object; continue }
		if fact.subject == tail && fact.predicate == first && fact.object == second_member_id do continue
		if fact.subject == tail && fact.predicate == rest && fact.object == nil do continue
		return {.Unsupported}
	}
	if tail == term.INVALID_TERM_ID || !store.contains(target, {subject = head, predicate = first, object = first_member_id}) || !store.contains(target, {subject = head, predicate = rest, object = tail}) || !store.contains(target, {subject = tail, predicate = first, object = second_member_id}) || !store.contains(target, {subject = tail, predicate = rest, object = nil}) do return {.Invalid_Certificate}
	return {.Model}
}

// verify_all_values_from_subclass_consistency_model checks the narrow shape
// C subClassOf [onProperty P; allValuesFrom D]. Give C an empty extension and
// P an empty relation; the restriction and the subclass statement then hold.
verify_all_values_from_subclass_consistency_model :: proc(target: ^store.Store, class, property, value_class: rdf.Term) -> Consistency_Model_Result {
	class_id := certificate_term_id(target, class)
	property_id := certificate_term_id(target, property)
	value_class_id := certificate_term_id(target, value_class)
	if class_id == term.INVALID_TERM_ID || property_id == term.INVALID_TERM_ID || value_class_id == term.INVALID_TERM_ID || class.kind != .IRI || property.kind != .IRI || value_class.kind != .IRI do return {.Invalid_Certificate}
	subclass := store.id_for_term(target, rdf.iri(rdfs.RDFS_SUBCLASS))
	on_property := store.id_for_term(target, rdf.iri(OWL_ON_PROPERTY))
	all_values_from := store.id_for_term(target, rdf.iri(OWL_ALL_VALUES_FROM))
	if subclass == term.INVALID_TERM_ID || on_property == term.INVALID_TERM_ID || all_values_from == term.INVALID_TERM_ID do return {.Unsupported}
	restriction := term.INVALID_TERM_ID
	for index in 0..<store.fact_count(target) {
		_, fact, _, found := store.fact_at(target, index)
		if !found do return {.Unsupported}
		if fact.subject == class_id && fact.predicate == subclass { restriction = fact.object; break }
	}
	if restriction == term.INVALID_TERM_ID do return {.Invalid_Certificate}
	for index in 0..<store.fact_count(target) {
		_, fact, origin, found := store.fact_at(target, index)
		if !found || origin != .Asserted do return {.Unsupported}
		if fact.subject == class_id && fact.predicate == subclass && fact.object == restriction do continue
		if fact.subject == restriction && fact.predicate == on_property && fact.object == property_id do continue
		if fact.subject == restriction && fact.predicate == all_values_from && fact.object == value_class_id do continue
		return {.Unsupported}
	}
	if !store.contains(target, {subject = restriction, predicate = on_property, object = property_id}) || !store.contains(target, {subject = restriction, predicate = all_values_from, object = value_class_id}) do return {.Invalid_Certificate}
	return {.Model}
}
