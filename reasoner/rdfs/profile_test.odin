package rdfs

import "core:testing"
import rdf "odin-rdf:rdf"
import importer "../import"
import rule "../rule"
import store "../store"
import term "../term"
import ntriples "odin-rdf:rdf/ntriples"

@(private) add :: proc(t: ^testing.T, target: ^store.Store, triple: rdf.Triple) {
	added, error := store.insert_triple(target, triple)
	testing.expect(t, added)
	testing.expect_value(t, error, store.Error_Code.None)
}

@(private) has :: proc(target: ^store.Store, triple: rdf.Triple) -> bool {
	fact := store.Fact{
		subject = term.id_for(&target.dictionary, triple.subject),
		predicate = term.id_for(&target.dictionary, triple.predicate),
		object = term.id_for(&target.dictionary, triple.object),
	}
	return fact.subject != term.INVALID_TERM_ID && fact.predicate != term.INVALID_TERM_ID && fact.object != term.INVALID_TERM_ID && store.contains(target, fact)
}

@(test)
test_all_rdfs_core_rules_and_composition :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)

	subclass := rdf.iri(RDFS_SUBCLASS)
	subproperty := rdf.iri(RDFS_SUBPROPERTY)
	type := rdf.iri(RDF_TYPE)
	domain := rdf.iri(RDFS_DOMAIN_IRI)
	range := rdf.iri(RDFS_RANGE_IRI)
	a, b, c := rdf.iri("urn:A"), rdf.iri("urn:B"), rdf.iri("urn:C")
	p1, p2, p3 := rdf.iri("urn:p1"), rdf.iri("urn:p2"), rdf.iri("urn:p3")
	x := rdf.iri("urn:x")
	blank := rdf.blank_node("object", rdf.Blank_Node_Scope(99))

	add(t, &target, {a, subclass, b})
	add(t, &target, {b, subclass, c})
	add(t, &target, {x, type, a})
	add(t, &target, {p1, subproperty, p2})
	add(t, &target, {p2, subproperty, p3})
	add(t, &target, {x, p1, rdf.literal("literal object")})
	add(t, &target, {p3, domain, c})
	add(t, &target, {p3, range, c})
	add(t, &target, {x, p3, blank})

	result := materialize(&profile, &target)
	testing.expect_value(t, result.error, rule.Error_Code.None)
	testing.expect(t, has(&target, {a, subclass, c}))
	testing.expect(t, has(&target, {x, type, b}))
	testing.expect(t, has(&target, {x, type, c}))
	testing.expect(t, has(&target, {p1, subproperty, p3}))
	testing.expect(t, has(&target, {x, p2, rdf.literal("literal object")}))
	testing.expect(t, has(&target, {x, p3, rdf.literal("literal object")}))
	testing.expect(t, has(&target, {blank, type, c}))
}

@(test)
test_cycles_duplicates_blank_nodes_and_literal_range_terminate :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	profile: Profile
	profile_error, _ := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	defer destroy(&profile)

	a, b := rdf.iri("urn:A"), rdf.iri("urn:B")
	x := rdf.blank_node("x", rdf.Blank_Node_Scope(1))
	add(t, &target, {a, rdf.iri(RDFS_SUBCLASS), b})
	add(t, &target, {b, rdf.iri(RDFS_SUBCLASS), a})
	add(t, &target, {x, rdf.iri(RDF_TYPE), a})
	add(t, &target, {rdf.iri("urn:p"), rdf.iri(RDFS_RANGE_IRI), b})
	add(t, &target, {x, rdf.iri("urn:p"), rdf.literal("v")})
	before := store.fact_count(&target)
	first := materialize(&profile, &target)
	testing.expect_value(t, first.error, rule.Error_Code.None)
	testing.expect(t, has(&target, {x, rdf.iri(RDF_TYPE), b}))
	after := store.fact_count(&target)
	testing.expect(t, after > before)
	second := materialize(&profile, &target)
	testing.expect_value(t, second.error, rule.Error_Code.None)
	testing.expect_value(t, second.inferred_facts, 0)
	testing.expect_value(t, store.fact_count(&target), after)
}

@(test)
test_pinned_w3c_rdfs_subproperty_semantics_vector :: proc(t: ^testing.T) {
	// The source and normalized local fixture are recorded in
	// conformance-ledger.md. This is the statement body of W3C
	// rdfs-subPropertyOf-semantics/test001.nt.
	input := `<http://example.org/bar> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/1999/02/22-rdf-syntax-ns#Property> .
<http://example.org/bas> <http://www.w3.org/2000/01/rdf-schema#subPropertyOf> <http://example.org/bar> .
<http://example.org/bar> <http://www.w3.org/2000/01/rdf-schema#domain> <http://example.org/Domain1> .
<http://example.org/bas> <http://www.w3.org/2000/01/rdf-schema#domain> <http://example.org/Domain2> .
<http://example.org/bar> <http://www.w3.org/2000/01/rdf-schema#range> <http://example.org/Range1> .
<http://example.org/bas> <http://www.w3.org/2000/01/rdf-schema#range> <http://example.org/Range2> .
<http://example.org/baz1> <http://example.org/bas> <http://example.org/baz2> .`
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	state: importer.Sink_State
	importer.init(&state, &target)
	parsed := ntriples.parse(input, importer.triple_sink, &state)
	testing.expect_value(t, parsed.code, ntriples.Error_Code.None)
	testing.expect_value(t, state.last_error, store.Error_Code.None)
	profile: Profile
	profile_error, store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, store_error, store.Error_Code.None)
	defer destroy(&profile)
	result := materialize(&profile, &target)
	testing.expect_value(t, result.error, rule.Error_Code.None)
	type_iri := rdf.iri(RDF_TYPE)
	baz1, baz2 := rdf.iri("http://example.org/baz1"), rdf.iri("http://example.org/baz2")
	testing.expect(t, has(&target, {baz1, type_iri, rdf.iri("http://example.org/Domain1")}))
	testing.expect(t, has(&target, {baz1, type_iri, rdf.iri("http://example.org/Domain2")}))
	testing.expect(t, has(&target, {baz2, type_iri, rdf.iri("http://example.org/Range1")}))
	testing.expect(t, has(&target, {baz2, type_iri, rdf.iri("http://example.org/Range2")}))
}

@(test)
test_pinned_w3c_rdfs_cycle_vectors_terminate_and_close :: proc(t: ^testing.T) {
	// These are the statement records of the two W3C Turtle inputs. The local
	// fixture is normalized to N-Triples because this package's parser boundary
	// is application-owned triples, not a Turtle reader.
	subclass_input := `<http://www.w3.org/2000/10/rdf-tests/rdfcore/rdfs-no-cycles-in-subClassOf/test001#A> <http://www.w3.org/2000/01/rdf-schema#subClassOf> <http://www.w3.org/2000/10/rdf-tests/rdfcore/rdfs-no-cycles-in-subClassOf/test001#B> .
<http://www.w3.org/2000/10/rdf-tests/rdfcore/rdfs-no-cycles-in-subClassOf/test001#B> <http://www.w3.org/2000/01/rdf-schema#subClassOf> <http://www.w3.org/2000/10/rdf-tests/rdfcore/rdfs-no-cycles-in-subClassOf/test001#A> .
<http://www.w3.org/2000/10/rdf-tests/rdfcore/rdfs-no-cycles-in-subClassOf/test001#X> <http://www.w3.org/2000/01/rdf-schema#subClassOf> <http://www.w3.org/2000/10/rdf-tests/rdfcore/rdfs-no-cycles-in-subClassOf/test001#X> .`
	subproperty_input := `<http://www.w3.org/2000/10/rdf-tests/rdfcore/rdfs-no-cycles-in-subPropertyOf/test001#A> <http://www.w3.org/2000/01/rdf-schema#subPropertyOf> <http://www.w3.org/2000/10/rdf-tests/rdfcore/rdfs-no-cycles-in-subPropertyOf/test001#B> .
<http://www.w3.org/2000/10/rdf-tests/rdfcore/rdfs-no-cycles-in-subPropertyOf/test001#B> <http://www.w3.org/2000/01/rdf-schema#subPropertyOf> <http://www.w3.org/2000/10/rdf-tests/rdfcore/rdfs-no-cycles-in-subPropertyOf/test001#A> .
<http://www.w3.org/2000/10/rdf-tests/rdfcore/rdfs-no-cycles-in-subPropertyOf/test001#X> <http://www.w3.org/2000/01/rdf-schema#subPropertyOf> <http://www.w3.org/2000/10/rdf-tests/rdfcore/rdfs-no-cycles-in-subPropertyOf/test001#X> .`

	inputs := [2]string{subclass_input, subproperty_input}
	for input in inputs {
		target: store.Store
		testing.expect_value(t, store.init(&target), store.Error_Code.None)
		state: importer.Sink_State
		importer.init(&state, &target)
		parsed := ntriples.parse(input, importer.triple_sink, &state)
		testing.expect_value(t, parsed.code, ntriples.Error_Code.None)
		testing.expect_value(t, state.last_error, store.Error_Code.None)
		profile: Profile
		profile_error, store_error := init(&profile, &target)
		testing.expect_value(t, profile_error, Error_Code.None)
		testing.expect_value(t, store_error, store.Error_Code.None)
		result := materialize(&profile, &target)
		testing.expect_value(t, result.error, rule.Error_Code.None)
		testing.expect(t, result.inferred_facts >= 2)
		destroy(&profile)
		store.destroy(&target)
	}
}
