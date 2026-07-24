package owlrl

import "core:testing"
import rdf "odin-rdf:rdf"
import ntriples "odin-rdf:rdf/ntriples"
import importer "../import"
import rule "../rule"
import store "../store"

@(private) run_pinned_w3c_positive_entailment :: proc(t: ^testing.T, input: string, conclusion: rdf.Triple) {
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
	testing.expect(t, has(&target, conclusion))
}

@(test)
test_pinned_w3c_owl_property_entailment_vectors :: proc(t: ^testing.T) {
	// The source documents and normalized local fixtures are recorded in
	// conformance-ledger.md. They are approved W3C OWL positive-entailment
	// vectors, expressed as application-owned N-Triples at this boundary.
	symmetric_input := `<http://www.w3.org/2002/03owlt/SymmetricProperty/premises001#Ghent> <http://www.w3.org/2002/03owlt/SymmetricProperty/premises001#path> <http://www.w3.org/2002/03owlt/SymmetricProperty/premises001#Antwerp> .
<http://www.w3.org/2002/03owlt/SymmetricProperty/premises001#path> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/2002/07/owl#SymmetricProperty> .`
	run_pinned_w3c_positive_entailment(t, symmetric_input, {
		rdf.iri("http://www.w3.org/2002/03owlt/SymmetricProperty/premises001#Antwerp"),
		rdf.iri("http://www.w3.org/2002/03owlt/SymmetricProperty/premises001#path"),
		rdf.iri("http://www.w3.org/2002/03owlt/SymmetricProperty/premises001#Ghent"),
	})

	transitive_input := `<http://www.w3.org/2002/03owlt/TransitiveProperty/premises001#Antwerp> <http://www.w3.org/2002/03owlt/TransitiveProperty/premises001#path> <http://www.w3.org/2002/03owlt/TransitiveProperty/premises001#Amsterdam> .
<http://www.w3.org/2002/03owlt/TransitiveProperty/premises001#Ghent> <http://www.w3.org/2002/03owlt/TransitiveProperty/premises001#path> <http://www.w3.org/2002/03owlt/TransitiveProperty/premises001#Antwerp> .
<http://www.w3.org/2002/03owlt/TransitiveProperty/premises001#path> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/2002/07/owl#TransitiveProperty> .`
	run_pinned_w3c_positive_entailment(t, transitive_input, {
		rdf.iri("http://www.w3.org/2002/03owlt/TransitiveProperty/premises001#Ghent"),
		rdf.iri("http://www.w3.org/2002/03owlt/TransitiveProperty/premises001#path"),
		rdf.iri("http://www.w3.org/2002/03owlt/TransitiveProperty/premises001#Amsterdam"),
	})

	functional_input := `<http://www.w3.org/2002/03owlt/FunctionalProperty/premises002#prop> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/2002/07/owl#FunctionalProperty> .
<http://www.w3.org/2002/03owlt/FunctionalProperty/premises002#object1> <http://www.example.org/prop2> "value" .
<http://www.w3.org/2002/03owlt/FunctionalProperty/premises002#subject> <http://www.w3.org/2002/03owlt/FunctionalProperty/premises002#prop> <http://www.w3.org/2002/03owlt/FunctionalProperty/premises002#object1> .
<http://www.w3.org/2002/03owlt/FunctionalProperty/premises002#subject> <http://www.w3.org/2002/03owlt/FunctionalProperty/premises002#prop> <http://www.w3.org/2002/03owlt/FunctionalProperty/premises002#object2> .`
	run_pinned_w3c_positive_entailment(t, functional_input, {
		rdf.iri("http://www.w3.org/2002/03owlt/FunctionalProperty/premises002#object2"),
		rdf.iri("http://www.example.org/prop2"),
		rdf.literal("value"),
	})
}
