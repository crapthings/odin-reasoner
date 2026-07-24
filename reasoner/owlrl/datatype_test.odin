package owlrl

import "core:testing"
import rdf "odin-rdf:rdf"
import rdfs "../rdfs"
import store "../store"

@(test)
test_generalized_datatype_materialization_derives_exact_type_equality_and_difference :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)

	decimal := "http://www.w3.org/2001/XMLSchema#decimal"
	integer := "http://www.w3.org/2001/XMLSchema#integer"
	token := "http://www.w3.org/2001/XMLSchema#token"
	nc_name := "http://www.w3.org/2001/XMLSchema#NCName"
	one_decimal := rdf.typed_literal("1.00", decimal)
	one_integer := rdf.typed_literal("1", integer)
	two_integer := rdf.typed_literal("2", integer)
	name := rdf.typed_literal("  local-name  ", token)
	add(t, &target, {rdf.iri("urn:s"), rdf.iri("urn:p"), one_decimal})
	add(t, &target, {rdf.iri("urn:s"), rdf.iri("urn:p"), one_integer})
	add(t, &target, {rdf.iri("urn:s"), rdf.iri("urn:p"), two_integer})
	add(t, &target, {rdf.iri("urn:s"), rdf.iri("urn:p"), name})

	result := materialize_generalized_datatypes(&profile, &target)
	testing.expect_value(t, result.error, Generalized_Datatype_Error_Code.None)
	testing.expect(t, has(&target, {one_decimal, rdf.iri(rdfs.RDF_TYPE), rdf.iri(integer)}))
	testing.expect(t, has(&target, {name, rdf.iri(rdfs.RDF_TYPE), rdf.iri(nc_name)}))
	testing.expect(t, has(&target, {one_decimal, rdf.iri(OWL_SAME_AS), one_integer}))
	testing.expect(t, has(&target, {one_decimal, rdf.iri(OWL_DIFFERENT_FROM), two_integer}))
	testing.expect(t, has(&target, {two_integer, rdf.iri(OWL_DIFFERENT_FROM), one_decimal}))
}

@(test)
test_generalized_datatype_materialization_limit_is_transactional :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)
	add(t, &target, {rdf.iri("urn:s"), rdf.iri("urn:p"), rdf.typed_literal("1", "http://www.w3.org/2001/XMLSchema#integer")})
	before := store.fact_count(&target)
	result := materialize_generalized_datatypes(&profile, &target, {max_derivations = 1})
	testing.expect_value(t, result.error, Generalized_Datatype_Error_Code.Rule_Error)
	testing.expect_value(t, store.fact_count(&target), before)
}
