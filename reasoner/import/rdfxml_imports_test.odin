package importer

import "core:testing"
import rdf "odin-rdf:rdf"
import store "../store"

@(private) Test_Resolver :: struct {
	first_iri:      string,
	first_document: string,
	second_iri:     string,
	second_document: string,
	calls:          int,
}

@(private) resolve_test_document :: proc(iri: string, user_data: rawptr) -> (string, bool) {
	state := cast(^Test_Resolver)user_data
	if state == nil do return "", false
	state.calls += 1
	if iri == state.first_iri do return state.first_document, true
	if iri == state.second_iri do return state.second_document, true
	return "", false
}

@(private) has_closure_triple :: proc(target: ^store.Store, triple: rdf.Triple) -> bool {
	return store.contains(target, {
		subject = store.id_for_term(target, triple.subject),
		predicate = store.id_for_term(target, triple.predicate),
		object = store.id_for_term(target, triple.object),
	})
}

@(test)
test_rdfxml_import_closure_deduplicates_a_cycle_and_commits_after_success :: proc(t: ^testing.T) {
	root := `<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:owl="http://www.w3.org/2002/07/owl#"><rdf:Description rdf:about="urn:root"><owl:imports rdf:resource="urn:a"/></rdf:Description></rdf:RDF>`
	a := `<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:owl="http://www.w3.org/2002/07/owl#" xmlns:ex="urn:"><rdf:Description rdf:about="urn:a"><owl:imports rdf:resource="urn:b"/><ex:seen rdf:resource="urn:yes"/></rdf:Description></rdf:RDF>`
	b := `<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:owl="http://www.w3.org/2002/07/owl#" xmlns:ex="urn:"><rdf:Description rdf:about="urn:b"><owl:imports rdf:resource="urn:a"/><ex:seen rdf:resource="urn:yes"/></rdf:Description></rdf:RDF>`
	resolver := Test_Resolver{first_iri = "urn:a", first_document = a, second_iri = "urn:b", second_document = b}
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	result := load_rdfxml_import_closure(root, &target, resolve_test_document, {}, &resolver)
	testing.expect_value(t, result.error, Import_Error_Code.None)
	testing.expect_value(t, result.documents, 3)
	testing.expect_value(t, resolver.calls, 2)
	testing.expect(t, has_closure_triple(&target, {rdf.iri("urn:a"), rdf.iri("urn:seen"), rdf.iri("urn:yes")}))
	testing.expect(t, has_closure_triple(&target, {rdf.iri("urn:b"), rdf.iri("urn:seen"), rdf.iri("urn:yes")}))
}

@(test)
test_rdfxml_import_closure_uses_root_iri_to_skip_a_self_import :: proc(t: ^testing.T) {
	root := `<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:owl="http://www.w3.org/2002/07/owl#" xmlns:ex="urn:"><rdf:Description rdf:about="urn:root"><owl:imports rdf:resource="urn:root"/><ex:seen rdf:resource="urn:yes"/></rdf:Description></rdf:RDF>`
	resolver := Test_Resolver{first_iri = "urn:root", first_document = root}
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	result := load_rdfxml_import_closure(root, &target, resolve_test_document, {root_iri = "urn:root"}, &resolver)
	testing.expect_value(t, result.error, Import_Error_Code.None)
	testing.expect_value(t, result.documents, 1)
	testing.expect_value(t, resolver.calls, 0)
	testing.expect(t, has_closure_triple(&target, {rdf.iri("urn:root"), rdf.iri("urn:seen"), rdf.iri("urn:yes")}))
}

@(test)
test_rdfxml_import_closure_failure_leaves_target_unchanged :: proc(t: ^testing.T) {
	sentinel := rdf.Triple{rdf.iri("urn:before"), rdf.iri("urn:kept"), rdf.iri("urn:value")}
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	added, insert_error := store.insert_triple(&target, sentinel)
	testing.expect(t, added)
	testing.expect_value(t, insert_error, store.Error_Code.None)
	before_terms, before_facts := store.term_count(&target), store.fact_count(&target)

	missing_document := `<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:owl="http://www.w3.org/2002/07/owl#"><rdf:Description rdf:about="urn:root"><owl:imports rdf:resource="urn:missing"/></rdf:Description></rdf:RDF>`
	missing := load_rdfxml_import_closure(missing_document, &target, resolve_test_document, {}, nil)
	testing.expect_value(t, missing.error, Import_Error_Code.Missing_Import)
	testing.expect_value(t, store.term_count(&target), before_terms)
	testing.expect_value(t, store.fact_count(&target), before_facts)
	testing.expect(t, has_closure_triple(&target, sentinel))

	limited_document := `<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:owl="http://www.w3.org/2002/07/owl#"><rdf:Description rdf:about="urn:root"><owl:imports rdf:resource="urn:a"/></rdf:Description></rdf:RDF>`
	limited_resolver: Test_Resolver
	limited := load_rdfxml_import_closure(limited_document, &target, resolve_test_document, {max_documents = 1}, &limited_resolver)
	testing.expect_value(t, limited.error, Import_Error_Code.Import_Limit)
	testing.expect_value(t, limited.documents, 1)
	testing.expect_value(t, limited_resolver.calls, 0)
	testing.expect_value(t, store.term_count(&target), before_terms)
	testing.expect_value(t, store.fact_count(&target), before_facts)
	testing.expect(t, has_closure_triple(&target, sentinel))
}

@(test)
test_rdfxml_import_closure_requires_a_resolver_without_mutating_target :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	document := `<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:owl="http://www.w3.org/2002/07/owl#"><rdf:Description rdf:about="urn:root"><owl:imports rdf:resource="urn:required"/></rdf:Description></rdf:RDF>`
	result := load_rdfxml_import_closure(document, &target)
	testing.expect_value(t, result.error, Import_Error_Code.Missing_Resolver)
	testing.expect_value(t, store.fact_count(&target), 0)
	testing.expect_value(t, store.term_count(&target), 0)
}
