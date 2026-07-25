package owlrl

import "core:testing"
import rdf "odin-rdf:rdf"
import rdfs "../rdfs"
import store "../store"
import term "../term"

@(test)
test_numeric_range_intersection_derives_exact_named_integer_ranges :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)

	range := rdf.iri(rdfs.RDFS_RANGE_IRI)
	property_one := rdf.iri("urn:intersection-one")
	property_two := rdf.iri("urn:intersection-two")
	short := rdf.iri("http://www.w3.org/2001/XMLSchema#short")
	unsigned_integer32 := rdf.iri("http://www.w3.org/2001/XMLSchema#unsignedInt")
	unsigned_short := rdf.iri("http://www.w3.org/2001/XMLSchema#unsignedShort")
	non_negative := rdf.iri("http://www.w3.org/2001/XMLSchema#nonNegativeInteger")
	non_positive := rdf.iri("http://www.w3.org/2001/XMLSchema#nonPositiveInteger")
	add(t, &target, {property_one, range, short})
	add(t, &target, {property_one, range, unsigned_integer32})
	add(t, &target, {property_two, range, non_negative})
	add(t, &target, {property_two, range, non_positive})

	result := materialize_all(&profile, &target)
	testing.expect_value(t, result.error, Materialize_All_Error_Code.None)
	testing.expect(t, has(&target, {property_one, range, unsigned_short}))
	testing.expect(t, has(&target, {property_two, range, short}))

	derived := store.id_for_fact(&target, {subject = term.id_for(&target.dictionary, property_one), predicate = term.id_for(&target.dictionary, range), object = term.id_for(&target.dictionary, unsigned_short)})
	derivation, found := closure_derivation_for(&profile, derived)
	testing.expect(t, found)
	testing.expect_value(t, derivation.rule_id, OWL_RDF_NUMERIC_RANGE_INTERSECTION)
	short_range := store.id_for_fact(&target, {subject = term.id_for(&target.dictionary, property_one), predicate = term.id_for(&target.dictionary, range), object = term.id_for(&target.dictionary, short)})
	unsigned_integer_range := store.id_for_fact(&target, {subject = term.id_for(&target.dictionary, property_one), predicate = term.id_for(&target.dictionary, range), object = term.id_for(&target.dictionary, unsigned_integer32)})
	testing.expect(t, closure_supports(derivation, short_range))
	testing.expect(t, closure_supports(derivation, unsigned_integer_range))
}
