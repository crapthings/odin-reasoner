// Package term provides owned RDF term interning for the reasoner core.
package term

import "core:strings"
import rdf "odin-rdf:rdf"

// Term_ID is opaque outside this package. Zero is never assigned to a term and
// is reserved as the wildcard value in store patterns.
Term_ID :: distinct u32
INVALID_TERM_ID :: Term_ID(0)

// Error_Code identifies dictionary validation, resource, and allocation
// failures. A successful lookup or intern returns None.
Error_Code :: enum {
	None,
	Invalid_Option,
	Invalid_Term,
	Term_Limit,
	Lexical_Bytes_Limit,
	Output_Length_Mismatch,
	Out_Of_Memory,
}

error_message :: proc(code: Error_Code) -> string {
	switch code {
	case .None:                   return "no error"
	case .Invalid_Option:         return "term limits must not be negative"
	case .Invalid_Term:           return "invalid RDF term"
	case .Term_Limit:             return "term limit reached"
	case .Lexical_Bytes_Limit:    return "lexical byte limit reached"
	case .Output_Length_Mismatch: return "term ID output length does not match input"
	case .Out_Of_Memory:          return "out of memory"
	}
	return "unknown error"
}

// Options governs owned dictionary admission. A zero limit disables it.
Options :: struct {
	max_terms:         int,
	max_lexical_bytes: int,
}

// Dictionary owns all returned RDF term strings until destroy. It is mutable
// and is not safe for concurrent mutation.
Dictionary :: struct {
	terms:             [dynamic]rdf.Term,
	owned:             [dynamic]string,
	keys:              [dynamic]string,
	term_ids:          map[string]Term_ID,
	max_terms:         int,
	max_lexical_bytes: int,
	lexical_bytes:     int,
}

init :: proc(dictionary: ^Dictionary, options: Options = {}) -> Error_Code {
	if options.max_terms < 0 || options.max_lexical_bytes < 0 do return .Invalid_Option
	dictionary^ = Dictionary{
		terms = make([dynamic]rdf.Term),
		owned = make([dynamic]string),
		keys = make([dynamic]string),
		term_ids = make(map[string]Term_ID),
		max_terms = options.max_terms,
		max_lexical_bytes = options.max_lexical_bytes,
	}
	return .None
}

// destroy frees all owned lexical strings. Any Term returned by get becomes
// invalid afterwards. Reinitialize before using the dictionary again.
destroy :: proc(dictionary: ^Dictionary) {
	for value in dictionary.owned do delete(value)
	for key in dictionary.keys do delete(key)
	delete(dictionary.term_ids)
	delete(dictionary.keys)
	delete(dictionary.owned)
	delete(dictionary.terms)
	dictionary^ = {}
}

count :: proc(dictionary: ^Dictionary) -> int { return len(dictionary.terms) }
owned_lexical_bytes :: proc(dictionary: ^Dictionary) -> int { return dictionary.lexical_bytes }

// get returns a borrowed term. The value's strings are owned by dictionary and
// remain valid until destroy; INVALID_TERM_ID and out-of-range IDs return false.
get :: proc(dictionary: ^Dictionary, id: Term_ID) -> (rdf.Term, bool) {
	index := int(id) - 1
	if id == INVALID_TERM_ID || index < 0 || index >= len(dictionary.terms) do return {}, false
	return dictionary.terms[index], true
}

@(private) ascii_equal_fold :: proc(left, right: string) -> bool {
	if len(left) != len(right) do return false
	for index in 0..<len(left) {
		a, b := left[index], right[index]
		if a >= 'A' && a <= 'Z' do a += 'a' - 'A'
		if b >= 'A' && b <= 'Z' do b += 'a' - 'A'
		if a != b do return false
	}
	return true
}

@(private) equal :: proc(left, right: rdf.Term) -> bool {
	if left.kind != right.kind || left.value != right.value || left.datatype != right.datatype do return false
	if !ascii_equal_fold(left.language, right.language) do return false
	if left.kind == .Blank_Node && left.scope != right.scope do return false
	return true
}

@(private) write_u64 :: proc(builder: ^strings.Builder, value: u64) {
	for shift := 56; shift >= 0; shift -= 8 do strings.write_byte(builder, byte((value >> u64(shift)) & 0xff))
}

// make_key frames every lexical component by byte length, so embedded NULs
// cannot collide. Language is normalized to ASCII lowercase to match RDF term
// equality. The returned string is caller-owned.
@(private) make_key :: proc(source: rdf.Term) -> (string, Error_Code) {
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	strings.write_byte(&builder, byte(source.kind))
	write_u64(&builder, u64(len(source.value)))
	strings.write_string(&builder, source.value)
	write_u64(&builder, u64(len(source.language)))
	for value in source.language {
		byte_value := byte(value)
		if byte_value >= 'A' && byte_value <= 'Z' do byte_value += 'a' - 'A'
		strings.write_byte(&builder, byte_value)
	}
	write_u64(&builder, u64(len(source.datatype)))
	strings.write_string(&builder, source.datatype)
	if source.kind == .Blank_Node do write_u64(&builder, u64(source.scope))
	key, alloc_error := strings.clone(strings.to_string(builder))
	if alloc_error != nil do return "", .Out_Of_Memory
	return key, .None
}

@(private) id_for_from :: proc(dictionary: ^Dictionary, source: rdf.Term) -> Term_ID {
	key, error := make_key(source)
	if error != .None do return INVALID_TERM_ID
	defer delete(key)
	id, found := dictionary.term_ids[key]
	if !found do return INVALID_TERM_ID
	return id
}

// id_for performs a non-mutating term lookup.
id_for :: proc(dictionary: ^Dictionary, source: rdf.Term) -> Term_ID {
	if rdf.validate_term_structure(source) != .None do return INVALID_TERM_ID
	return id_for_from(dictionary, source)
}

@(private) lexical_size :: proc(source: rdf.Term) -> int {
	return len(source.value) + len(source.language) + len(source.datatype)
}

@(private) copy_string :: proc(dictionary: ^Dictionary, source: string) -> (string, Error_Code) {
	if len(source) == 0 do return "", .None
	owned, alloc_error := strings.clone(source)
	if alloc_error != nil do return "", .Out_Of_Memory
	_, append_error := append(&dictionary.owned, owned)
	if append_error != nil {
		delete(owned)
		return "", .Out_Of_Memory
	}
	return owned, .None
}

@(private) discard_owned_from :: proc(dictionary: ^Dictionary, start: int) {
	for index in start..<len(dictionary.owned) do delete(dictionary.owned[index])
	resize(&dictionary.owned, start)
}

@(private) append_owned_term :: proc(dictionary: ^Dictionary, source: rdf.Term) -> Error_Code {
	owned_start := len(dictionary.owned)
	stored := source
	error: Error_Code
	stored.value, error = copy_string(dictionary, source.value)
	if error != .None { discard_owned_from(dictionary, owned_start); return error }
	stored.language, error = copy_string(dictionary, source.language)
	if error != .None { discard_owned_from(dictionary, owned_start); return error }
	stored.datatype, error = copy_string(dictionary, source.datatype)
	if error != .None { discard_owned_from(dictionary, owned_start); return error }
	key, key_error := make_key(source)
	if key_error != .None { discard_owned_from(dictionary, owned_start); return key_error }
	_, append_error := append(&dictionary.terms, stored)
	if append_error != nil {
		delete(key)
		discard_owned_from(dictionary, owned_start)
		return .Out_Of_Memory
	}
	_, key_append_error := append(&dictionary.keys, key)
	if key_append_error != nil {
		resize(&dictionary.terms, len(dictionary.terms) - 1)
		delete(key)
		discard_owned_from(dictionary, owned_start)
		return .Out_Of_Memory
	}
	dictionary.term_ids[key] = Term_ID(len(dictionary.terms))
	dictionary.lexical_bytes += lexical_size(source)
	return .None
}

// intern_batch interns terms atomically with respect to declared resource
// limits. IDs must have the same length as terms. Equal input terms receive the
// same ID; no lexical data borrowed from the caller is retained.
intern_batch :: proc(dictionary: ^Dictionary, sources: []rdf.Term, ids: []Term_ID) -> Error_Code {
	if len(sources) != len(ids) do return .Output_Length_Mismatch

	new_count := 0
	new_bytes := 0
	for source, index in sources {
		if rdf.validate_term_structure(source) != .None do return .Invalid_Term
		found := id_for_from(dictionary, source)
		if found != INVALID_TERM_ID {
			ids[index] = found
			continue
		}
		duplicate := false
		for prior in 0..<index {
			if equal(sources[prior], source) {
				duplicate = true
				break
			}
		}
		if duplicate do continue
		new_count += 1
		new_bytes += lexical_size(source)
	}
	if dictionary.max_terms > 0 && len(dictionary.terms) + new_count > dictionary.max_terms do return .Term_Limit
	if dictionary.max_lexical_bytes > 0 && dictionary.lexical_bytes + new_bytes > dictionary.max_lexical_bytes do return .Lexical_Bytes_Limit

	for source, index in sources {
		if ids[index] != INVALID_TERM_ID do continue
		if error := append_owned_term(dictionary, source); error != .None do return error
		ids[index] = Term_ID(len(dictionary.terms))
		for later in index + 1..<len(sources) {
			if ids[later] == INVALID_TERM_ID && equal(sources[later], source) do ids[later] = ids[index]
		}
	}
	return .None
}

// intern is the single-term convenience wrapper around intern_batch.
intern :: proc(dictionary: ^Dictionary, source: rdf.Term) -> (Term_ID, Error_Code) {
	ids: [1]Term_ID
	error := intern_batch(dictionary, []rdf.Term{source}, ids[:])
	return ids[0], error
}
