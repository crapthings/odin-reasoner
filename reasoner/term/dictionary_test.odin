package term

import "core:testing"
import rdf "odin-rdf:rdf"

@(test)
test_intern_owns_and_deduplicates_terms :: proc(t: ^testing.T) {
	dictionary: Dictionary
	testing.expect_value(t, init(&dictionary), Error_Code.None)
	defer destroy(&dictionary)

	first, first_error := intern(&dictionary, rdf.language_literal("tea", "EN-gb"))
	second, second_error := intern(&dictionary, rdf.language_literal("tea", "en-GB"))
	testing.expect_value(t, first_error, Error_Code.None)
	testing.expect_value(t, second_error, Error_Code.None)
	testing.expect_value(t, first, second)
	testing.expect_value(t, count(&dictionary), 1)
	stored, found := get(&dictionary, first)
	testing.expect(t, found)
	testing.expect_value(t, stored.value, "tea")
	testing.expect_value(t, stored.language, "EN-gb")
}

@(test)
test_blank_node_scope_is_part_of_identity :: proc(t: ^testing.T) {
	dictionary: Dictionary
	testing.expect_value(t, init(&dictionary), Error_Code.None)
	defer destroy(&dictionary)

	a, a_error := intern(&dictionary, rdf.blank_node("same", rdf.Blank_Node_Scope(1)))
	b, b_error := intern(&dictionary, rdf.blank_node("same", rdf.Blank_Node_Scope(2)))
	c, c_error := intern(&dictionary, rdf.blank_node("same", rdf.Blank_Node_Scope(1)))
	testing.expect_value(t, a_error, Error_Code.None)
	testing.expect_value(t, b_error, Error_Code.None)
	testing.expect_value(t, c_error, Error_Code.None)
	testing.expect(t, a != b)
	testing.expect_value(t, a, c)
	}

@(test)
test_budget_failure_does_not_mutate_dictionary :: proc(t: ^testing.T) {
	dictionary: Dictionary
	testing.expect_value(t, init(&dictionary, {max_terms = 1, max_lexical_bytes = 8}), Error_Code.None)
	defer destroy(&dictionary)

	first, first_error := intern(&dictionary, rdf.iri("urn:a"))
	testing.expect_value(t, first_error, Error_Code.None)
	testing.expect(t, first != INVALID_TERM_ID)
	before_terms, before_bytes := count(&dictionary), owned_lexical_bytes(&dictionary)
	_, term_error := intern(&dictionary, rdf.iri("urn:b"))
	testing.expect_value(t, term_error, Error_Code.Term_Limit)
	testing.expect_value(t, count(&dictionary), before_terms)
	testing.expect_value(t, owned_lexical_bytes(&dictionary), before_bytes)
}
