package owlrl

import "core:testing"
import rdf "odin-rdf:rdf"
import importer "../import"
import store "../store"

@(private) W3C_Import_Resolver :: struct {
	iri:      string,
	document: string,
}

@(private) resolve_w3c_import :: proc(iri: string, user_data: rawptr) -> (string, bool) {
	state := cast(^W3C_Import_Resolver)user_data
	if state == nil || iri != state.iri do return "", false
	return state.document, true
}

@(private) has_import_closure_triple :: proc(target: ^store.Store, triple: rdf.Triple) -> bool {
	return store.contains(target, {
		subject = store.id_for_term(target, triple.subject),
		predicate = store.id_for_term(target, triple.predicate),
		object = store.id_for_term(target, triple.object),
	})
}

@(test)
test_rdfxml_import_closure_proves_w3c_imports_011_entailment :: proc(t: ^testing.T) {
	root_document := `<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#" xmlns:owl="http://www.w3.org/2002/07/owl#" xmlns:ont="http://www.w3.org/2002/03owlt/imports/support011-A#" xml:base="http://www.w3.org/2002/03owlt/imports/premises011"><owl:Ontology rdf:about=""><owl:imports rdf:resource="http://www.w3.org/2002/03owlt/imports/support011-A"/></owl:Ontology><ont:Man rdf:about="http://example.org/data#Socrates"/></rdf:RDF>`
	imported_document := `<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#" xmlns:owl="http://www.w3.org/2002/07/owl#" xml:base="http://www.w3.org/2002/03owlt/imports/support011-A"><owl:Ontology rdf:about=""/><owl:Class rdf:ID="Man"><rdfs:subClassOf rdf:resource="#Mortal"/></owl:Class><owl:Class rdf:ID="Mortal"/></rdf:RDF>`
	resolver := W3C_Import_Resolver{iri = "http://www.w3.org/2002/03owlt/imports/support011-A", document = imported_document}
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	loaded := importer.load_rdfxml_import_closure(root_document, &target, resolve_w3c_import, {root_iri = "http://www.w3.org/2002/03owlt/imports/premises011"}, &resolver)
	testing.expect_value(t, loaded.error, importer.Import_Error_Code.None)
	testing.expect_value(t, loaded.documents, 2)
	profile: Profile
	profile_error, profile_store_error := init(&profile, &target)
	testing.expect_value(t, profile_error, Error_Code.None)
	testing.expect_value(t, profile_store_error, store.Error_Code.None)
	defer destroy(&profile)
	materialized := materialize_all(&profile, &target)
	testing.expect_value(t, materialized.error, Materialize_All_Error_Code.None)
	testing.expect(t, has_import_closure_triple(&target, {rdf.iri("http://example.org/data#Socrates"), rdf.iri("http://www.w3.org/1999/02/22-rdf-syntax-ns#type"), rdf.iri("http://www.w3.org/2002/03owlt/imports/support011-A#Mortal")}))
}
