package importer

import "core:testing"
import rdf "odin-rdf:rdf"
import rdfxml "odin-rdf:rdf/rdfxml"
import store "../store"
import turtle "odin-rdf:rdf/turtle"

@(test)
test_turtle_sink_immediately_owns_terms_and_preserves_blank_scopes :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	state: Sink_State
	init(&state, &target)

	first := turtle.parse("_:same <urn:p> \"first\" .", triple_sink, {}, &state)
	second := turtle.parse("_:same <urn:p> \"second\" .", triple_sink, {}, &state)
	testing.expect_value(t, first.code, turtle.Error_Code.None)
	testing.expect_value(t, second.code, turtle.Error_Code.None)
	testing.expect_value(t, state.last_error, store.Error_Code.None)
	testing.expect_value(t, state.inserted, 2)
	testing.expect_value(t, store.fact_count(&target), 2)
	testing.expect_value(t, store.term_count(&target), 5)

	triple, found := store.triple_for(&target, store.Fact_ID(1))
	second_triple, second_found := store.triple_for(&target, store.Fact_ID(2))
	testing.expect(t, found)
	testing.expect(t, second_found)
	testing.expect_value(t, triple.subject.kind, rdf.Term_Kind.Blank_Node)
	testing.expect_value(t, triple.subject.value, "same")
	testing.expect_value(t, triple.object.value, "first")
	testing.expect(t, triple.subject.scope != second_triple.subject.scope)
}

@(test)
test_sink_exposes_limit_error_to_parser :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target, {max_facts = 1}), store.Error_Code.None)
	defer store.destroy(&target)
	state: Sink_State
	init(&state, &target)
	result := turtle.parse("<urn:s1> <urn:p> <urn:o> . <urn:s2> <urn:p> <urn:o> .", triple_sink, {}, &state)
	testing.expect_value(t, result.code, turtle.Error_Code.Stopped)
	testing.expect_value(t, state.last_error, store.Error_Code.Fact_Limit)
	testing.expect_value(t, store.fact_count(&target), 1)
}

@(test)
test_rdfxml_quad_sink_owns_default_graph_statements :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	state: Sink_State
	init(&state, &target)
	document := `<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:ex="http://example.org/"><rdf:Description rdf:about="http://example.org/s"><ex:p rdf:resource="http://example.org/o"/></rdf:Description></rdf:RDF>`
	parsed := rdfxml.parse(document, quad_sink, {}, &state)
	testing.expect_value(t, parsed.code, rdfxml.Error_Code.None)
	testing.expect_value(t, state.last_error, store.Error_Code.None)
	testing.expect(t, !state.rejected_named_graph)
	testing.expect_value(t, state.inserted, 1)
	testing.expect(t, store.contains(&target, {
		subject = store.id_for_term(&target, rdf.iri("http://example.org/s")),
		predicate = store.id_for_term(&target, rdf.iri("http://example.org/p")),
		object = store.id_for_term(&target, rdf.iri("http://example.org/o")),
	}))
}

@(test)
test_quad_sink_rejects_named_graphs_without_flattening :: proc(t: ^testing.T) {
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	defer store.destroy(&target)
	state: Sink_State
	init(&state, &target)
	accepted := quad_sink(rdf.named_graph_quad({rdf.iri("urn:s"), rdf.iri("urn:p"), rdf.iri("urn:o")}, rdf.iri("urn:graph")), &state)
	testing.expect(t, !accepted)
	testing.expect(t, state.rejected_named_graph)
	testing.expect_value(t, store.fact_count(&target), 0)
}

@(private) has_import_triple :: proc(target: ^store.Store, triple: rdf.Triple) -> bool {
	return store.contains(target, {
		subject = store.id_for_term(target, triple.subject),
		predicate = store.id_for_term(target, triple.predicate),
		object = store.id_for_term(target, triple.object),
	})
}

@(private) parse_rdfxml_into_store :: proc(input: string, target: ^store.Store) -> rdfxml.Parse_Error {
	state: Sink_State
	init(&state, target)
	result := rdfxml.parse(input, quad_sink, {}, &state)
	return result
}

@(test)
test_rdfxml_adapter_preserves_w3c_annotation_and_axiom_reification_shapes :: proc(t: ^testing.T) {
	annotation_document := `<rdf:RDF xml:base="http://example.org/" xmlns="http://example.org/" xmlns:owl="http://www.w3.org/2002/07/owl#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"><owl:Ontology rdf:about="http://example.org/"/><rdf:Description rdf:about="http://example.org/"><rdfs:label>An example ontology</rdfs:label></rdf:Description><owl:Annotation><owl:annotatedSource rdf:resource="http://example.org/"/><owl:annotatedProperty rdf:resource="http://www.w3.org/2000/01/rdf-schema#label"/><owl:annotatedTarget>An example ontology</owl:annotatedTarget><author>Mike Smith</author></owl:Annotation><owl:AnnotationProperty rdf:about="http://example.org/author"/></rdf:RDF>`
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	result := parse_rdfxml_into_store(annotation_document, &target)
	testing.expect_value(t, result.code, rdfxml.Error_Code.None)
	testing.expect(t, has_import_triple(&target, {rdf.iri("http://example.org/"), rdf.iri("http://www.w3.org/2000/01/rdf-schema#label"), rdf.literal("An example ontology")}))
	author := store.id_for_term(&target, rdf.iri("http://example.org/author"))
	author_found := false
	for index in 0..<store.fact_count(&target) {
		_, fact, _, found := store.fact_at(&target, index)
		if found && fact.predicate == author { author_found = true; break }
	}
	testing.expect(t, author_found)
	store.destroy(&target)

	axiom_document := `<rdf:RDF xml:base="http://example.org/" xmlns="http://example.org/" xmlns:owl="http://www.w3.org/2002/07/owl#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"><owl:Ontology/><owl:Class rdf:about="http://example.org/Child"/><owl:Class rdf:about="http://example.org/Person"/><rdf:Description rdf:about="http://example.org/Child"><rdfs:subClassOf rdf:resource="http://example.org/Person"/></rdf:Description><owl:Axiom><owl:annotatedSource rdf:resource="http://example.org/Child"/><owl:annotatedProperty rdf:resource="http://www.w3.org/2000/01/rdf-schema#subClassOf"/><owl:annotatedTarget rdf:resource="http://example.org/Person"/><rdfs:comment>Children are people.</rdfs:comment></owl:Axiom></rdf:RDF>`
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	result = parse_rdfxml_into_store(axiom_document, &target)
	testing.expect_value(t, result.code, rdfxml.Error_Code.None)
	testing.expect(t, has_import_triple(&target, {rdf.iri("http://example.org/Child"), rdf.iri("http://www.w3.org/2000/01/rdf-schema#subClassOf"), rdf.iri("http://example.org/Person")}))
	annotated_source := store.id_for_term(&target, rdf.iri("http://www.w3.org/2002/07/owl#annotatedSource"))
	reified := false
	for index in 0..<store.fact_count(&target) {
		_, fact, _, found := store.fact_at(&target, index)
		if found && fact.predicate == annotated_source && fact.object == store.id_for_term(&target, rdf.iri("http://example.org/Child")) { reified = true; break }
	}
	testing.expect(t, reified)
	store.destroy(&target)
}

@(test)
test_rdfxml_adapter_preserves_w3c_annotation_property_and_metadata_shapes :: proc(t: ^testing.T) {
	annotation_property := `<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:owl="http://www.w3.org/2002/07/owl#" xmlns:first="http://www.w3.org/2002/03owlt/AnnotationProperty/consistent003#" xml:base="http://www.w3.org/2002/03owlt/AnnotationProperty/consistent003"><owl:Ontology/><owl:AnnotationProperty rdf:ID="ap"/><owl:Class rdf:ID="A"><first:ap><rdf:Description rdf:ID="B"/></first:ap></owl:Class></rdf:RDF>`
	target: store.Store
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	result := parse_rdfxml_into_store(annotation_property, &target)
	testing.expect_value(t, result.code, rdfxml.Error_Code.None)
	testing.expect(t, has_import_triple(&target, {rdf.iri("http://www.w3.org/2002/03owlt/AnnotationProperty/consistent003#A"), rdf.iri("http://www.w3.org/2002/03owlt/AnnotationProperty/consistent003#ap"), rdf.iri("http://www.w3.org/2002/03owlt/AnnotationProperty/consistent003#B")}))
	store.destroy(&target)

	annotation_range := `<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#" xmlns:owl="http://www.w3.org/2002/07/owl#" xml:base="http://www.w3.org/2002/03owlt/AnnotationProperty/consistent004"><owl:Ontology/><owl:AnnotationProperty rdf:ID="ap"><rdfs:range rdf:resource="http://www.w3.org/2001/XMLSchema#string"/></owl:AnnotationProperty></rdf:RDF>`
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	result = parse_rdfxml_into_store(annotation_range, &target)
	testing.expect_value(t, result.code, rdfxml.Error_Code.None)
	testing.expect(t, has_import_triple(&target, {rdf.iri("http://www.w3.org/2002/03owlt/AnnotationProperty/consistent004#ap"), rdf.iri("http://www.w3.org/2000/01/rdf-schema#range"), rdf.iri("http://www.w3.org/2001/XMLSchema#string")}))
	store.destroy(&target)

	backward_compatible := `<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:owl="http://www.w3.org/2002/07/owl#"><rdf:Description><owl:backwardCompatibleWith><owl:Ontology rdf:about="http://www.example.org/"/></owl:backwardCompatibleWith></rdf:Description></rdf:RDF>`
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	result = parse_rdfxml_into_store(backward_compatible, &target)
	testing.expect_value(t, result.code, rdfxml.Error_Code.None)
	backward := store.id_for_term(&target, rdf.iri("http://www.w3.org/2002/07/owl#backwardCompatibleWith"))
	backward_found := false
	for index in 0..<store.fact_count(&target) {
		_, fact, _, found := store.fact_at(&target, index)
		if found && fact.predicate == backward && fact.object == store.id_for_term(&target, rdf.iri("http://www.example.org/")) { backward_found = true; break }
	}
	testing.expect(t, backward_found)
	store.destroy(&target)

	miscellaneous := `<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:owl="http://www.w3.org/2002/07/owl#"><owl:Ontology/><owl:AnnotationProperty rdf:about="http://purl.org/dc/elements/1.0/creator"/></rdf:RDF>`
	testing.expect_value(t, store.init(&target), store.Error_Code.None)
	result = parse_rdfxml_into_store(miscellaneous, &target)
	testing.expect_value(t, result.code, rdfxml.Error_Code.None)
	testing.expect(t, has_import_triple(&target, {rdf.iri("http://purl.org/dc/elements/1.0/creator"), rdf.iri("http://www.w3.org/1999/02/22-rdf-syntax-ns#type"), rdf.iri("http://www.w3.org/2002/07/owl#AnnotationProperty")}))
	store.destroy(&target)
}
