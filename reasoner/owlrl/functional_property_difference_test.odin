package owlrl

import "core:testing"
import rdf "odin-rdf:rdf"
import rdfs "../rdfs"
import store "../store"
import term "../term"

@(test)
test_functional_property_difference_preserves_explicit_inequality :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)

	functional, inverse_functional := rdf.iri("urn:functional"), rdf.iri("urn:inverse-functional")
	a, b, left, right := rdf.iri("urn:a"), rdf.iri("urn:b"), rdf.iri("urn:left"), rdf.iri("urn:right")
	c, d, first, second := rdf.iri("urn:c"), rdf.iri("urn:d"), rdf.iri("urn:first"), rdf.iri("urn:second")
	add(t, &target, {functional, rdf.iri(rdfs.RDF_TYPE), rdf.iri(OWL_FUNCTIONAL_PROPERTY)})
	add(t, &target, {a, functional, left})
	add(t, &target, {b, functional, right})
	add(t, &target, {left, rdf.iri(OWL_DIFFERENT_FROM), right})
	add(t, &target, {inverse_functional, rdf.iri(rdfs.RDF_TYPE), rdf.iri(OWL_INVERSE_FUNCTIONAL_PROPERTY)})
	add(t, &target, {c, inverse_functional, first})
	add(t, &target, {d, inverse_functional, second})
	add(t, &target, {c, rdf.iri(OWL_DIFFERENT_FROM), d})

	result := materialize_all(&profile, &target)
	testing.expect_value(t, result.error, Materialize_All_Error_Code.None)
	testing.expect(t, has(&target, {a, rdf.iri(OWL_DIFFERENT_FROM), b}))
	testing.expect(t, has(&target, {first, rdf.iri(OWL_DIFFERENT_FROM), second}))

	functional_fact := store.id_for_fact(&target, {subject = term.id_for(&target.dictionary, a), predicate = term.id_for(&target.dictionary, rdf.iri(OWL_DIFFERENT_FROM)), object = term.id_for(&target.dictionary, b)})
	functional_derivation, functional_found := closure_derivation_for(&profile, functional_fact)
	testing.expect(t, functional_found)
	testing.expect_value(t, functional_derivation.rule_id, OWL_RDF_FUNCTIONAL_PROPERTY_DIFFERENCE)
	testing.expect(t, closure_supports(functional_derivation, store.id_for_fact(&target, {subject = term.id_for(&target.dictionary, left), predicate = term.id_for(&target.dictionary, rdf.iri(OWL_DIFFERENT_FROM)), object = term.id_for(&target.dictionary, right)})))

	inverse_fact := store.id_for_fact(&target, {subject = term.id_for(&target.dictionary, first), predicate = term.id_for(&target.dictionary, rdf.iri(OWL_DIFFERENT_FROM)), object = term.id_for(&target.dictionary, second)})
	inverse_derivation, inverse_found := closure_derivation_for(&profile, inverse_fact)
	testing.expect(t, inverse_found)
	testing.expect_value(t, inverse_derivation.rule_id, OWL_RDF_INVERSE_FUNCTIONAL_PROPERTY_DIFFERENCE)
	testing.expect(t, closure_supports(inverse_derivation, store.id_for_fact(&target, {subject = term.id_for(&target.dictionary, c), predicate = term.id_for(&target.dictionary, rdf.iri(OWL_DIFFERENT_FROM)), object = term.id_for(&target.dictionary, d)})))
}
