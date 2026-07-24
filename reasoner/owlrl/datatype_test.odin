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
	date_time := "http://www.w3.org/2001/XMLSchema#dateTime"
	date_time_stamp := "http://www.w3.org/2001/XMLSchema#dateTimeStamp"
	time_with_z := rdf.typed_literal("2024-01-01T00:00:00Z", date_time)
	time_with_zero_offset := rdf.typed_literal("2024-01-01T00:00:00+00:00", date_time_stamp)
	// Equal instants with distinct offset properties are distinct XML Schema
	// data values; OWL RL dt-eq/dt-diff use data-value identity.
	time_with_negative_offset := rdf.typed_literal("2023-12-31T19:00:00-05:00", date_time)
	add(t, &target, {rdf.iri("urn:s"), rdf.iri("urn:p"), one_decimal})
	add(t, &target, {rdf.iri("urn:s"), rdf.iri("urn:p"), one_integer})
	add(t, &target, {rdf.iri("urn:s"), rdf.iri("urn:p"), two_integer})
	add(t, &target, {rdf.iri("urn:s"), rdf.iri("urn:p"), name})
	add(t, &target, {rdf.iri("urn:s"), rdf.iri("urn:p"), time_with_z})
	add(t, &target, {rdf.iri("urn:s"), rdf.iri("urn:p"), time_with_zero_offset})
	add(t, &target, {rdf.iri("urn:s"), rdf.iri("urn:p"), time_with_negative_offset})

	result := materialize_generalized_datatypes(&profile, &target)
	testing.expect_value(t, result.error, Generalized_Datatype_Error_Code.None)
	testing.expect(t, has(&target, {one_decimal, rdf.iri(rdfs.RDF_TYPE), rdf.iri(integer)}))
	testing.expect(t, has(&target, {name, rdf.iri(rdfs.RDF_TYPE), rdf.iri(nc_name)}))
	testing.expect(t, has(&target, {one_decimal, rdf.iri(OWL_SAME_AS), one_integer}))
	testing.expect(t, has(&target, {one_decimal, rdf.iri(OWL_DIFFERENT_FROM), two_integer}))
	testing.expect(t, has(&target, {two_integer, rdf.iri(OWL_DIFFERENT_FROM), one_decimal}))
	testing.expect(t, has(&target, {time_with_z, rdf.iri(OWL_SAME_AS), time_with_zero_offset}))
	testing.expect(t, has(&target, {time_with_z, rdf.iri(OWL_DIFFERENT_FROM), time_with_negative_offset}))
	testing.expect(t, has(&target, {time_with_negative_offset, rdf.iri(OWL_DIFFERENT_FROM), time_with_z}))
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

@(test)
test_generalized_datatype_checked_reports_dt_not_type :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)
	report: Report
	init_report(&report)
	defer destroy_report(&report)

	literal_id, literal_error := store.intern_term(&target, rdf.typed_literal("256", "http://www.w3.org/2001/XMLSchema#integer"))
	testing.expect_value(t, literal_error, store.Error_Code.None)
	unsigned_byte := rdf.iri("http://www.w3.org/2001/XMLSchema#unsignedByte")
	unsigned_byte_id := store.id_for_term(&target, unsigned_byte)
	testing.expect(t, unsigned_byte_id != 0)
	added, insert_error := store.insert(&target, {subject = literal_id, predicate = profile.terms.rdf_type, object = unsigned_byte_id}, .Asserted)
	testing.expect(t, added)
	testing.expect_value(t, insert_error, store.Error_Code.None)

	result := materialize_generalized_datatypes_checked(&profile, &target, &report)
	testing.expect_value(t, result.materialization.error, Generalized_Datatype_Error_Code.None)
	testing.expect_value(t, result.consistency, Consistency_Error_Code.None)
	testing.expect(t, !result.consistent)
	testing.expect(t, has_kind(&report, .Datatype_Not_Type))
}
