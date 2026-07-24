// Package store implements the bounded, set-semantics triple fact store.
package store

import rdf "odin-rdf:rdf"
import term "../term"

// Fact_ID identifies one retained triple. Zero is never a valid fact ID.
Fact_ID :: distinct u32
INVALID_FACT_ID :: Fact_ID(0)

// Fact is the compact, interned representation of an RDF triple.
Fact :: struct {
	subject:   term.Term_ID,
	predicate: term.Term_ID,
	object:    term.Term_ID,
}

// Origin records the first successful insertion source for a fact. Duplicate
// insertion never changes it.
Origin :: enum { Asserted, Inferred }

// Error_Code reports validation, admission, and allocation failure.
Error_Code :: enum {
	None,
	Invalid_Option,
	Invalid_Triple,
	Invalid_Fact,
	Term_Limit,
	Lexical_Bytes_Limit,
	Fact_Limit,
	Missing_Sink,
	Out_Of_Memory,
}

error_message :: proc(code: Error_Code) -> string {
	switch code {
	case .None:                return "no error"
	case .Invalid_Option:      return "store limits must not be negative"
	case .Invalid_Triple:      return "invalid RDF triple"
	case .Invalid_Fact:        return "fact refers to an unknown term"
	case .Term_Limit:          return "term limit reached"
	case .Lexical_Bytes_Limit: return "lexical byte limit reached"
	case .Fact_Limit:          return "fact limit reached"
	case .Missing_Sink:        return "match sink is required"
	case .Out_Of_Memory:       return "out of memory"
	}
	return "unknown error"
}

// Options bounds retained storage. Each zero field disables that limit.
Options :: struct {
	max_terms:         int,
	max_lexical_bytes: int,
	max_facts:         int,
}

// Pattern uses term.INVALID_TERM_ID as a wildcard in each position.
Pattern :: struct {
	subject:   term.Term_ID,
	predicate: term.Term_ID,
	object:    term.Term_ID,
}

// Match_Sink receives borrowed fact data. Returning false requests normal
// early stop; Match_Result.stopped distinguishes it from an error.
Match_Sink :: proc(id: Fact_ID, fact: Fact, origin: Origin, user_data: rawptr) -> bool

Match_Result :: struct {
	error:   Error_Code,
	matched: int,
	stopped: bool,
}

@(private) Record :: struct { fact: Fact, origin: Origin }
@(private) Pair :: struct { left, right: term.Term_ID }
@(private) Bucket :: struct { ids: [dynamic]Fact_ID }
@(private) One_Index :: struct { by_key: map[term.Term_ID]int, buckets: [dynamic]Bucket }
@(private) Two_Index :: struct { by_key: map[Pair]int, buckets: [dynamic]Bucket }

// Store owns its term dictionary, facts, and indexes until destroy.
Store :: struct {
	dictionary: term.Dictionary,
	facts:      [dynamic]Record,
	fact_ids:   map[Fact]Fact_ID,
	by_subject: One_Index,
	by_predicate: One_Index,
	by_object: One_Index,
	by_subject_predicate: Two_Index,
	by_subject_object: Two_Index,
	by_predicate_object: Two_Index,
	max_facts: int,
}

@(private) init_one_index :: proc(index: ^One_Index) {
	index^ = One_Index{by_key = make(map[term.Term_ID]int), buckets = make([dynamic]Bucket)}
}

@(private) init_two_index :: proc(index: ^Two_Index) {
	index^ = Two_Index{by_key = make(map[Pair]int), buckets = make([dynamic]Bucket)}
}

@(private) destroy_one_index :: proc(index: ^One_Index) {
	for bucket in index.buckets do delete(bucket.ids)
	delete(index.buckets)
	delete(index.by_key)
	index^ = {}
}

@(private) destroy_two_index :: proc(index: ^Two_Index) {
	for bucket in index.buckets do delete(bucket.ids)
	delete(index.buckets)
	delete(index.by_key)
	index^ = {}
}

init :: proc(store: ^Store, options: Options = {}) -> Error_Code {
	if options.max_terms < 0 || options.max_lexical_bytes < 0 || options.max_facts < 0 do return .Invalid_Option
	term_error := term.init(&store.dictionary, {max_terms = options.max_terms, max_lexical_bytes = options.max_lexical_bytes})
	if term_error != .None do return .Invalid_Option
	store.facts = make([dynamic]Record)
	store.fact_ids = make(map[Fact]Fact_ID)
	init_one_index(&store.by_subject)
	init_one_index(&store.by_predicate)
	init_one_index(&store.by_object)
	init_two_index(&store.by_subject_predicate)
	init_two_index(&store.by_subject_object)
	init_two_index(&store.by_predicate_object)
	store.max_facts = options.max_facts
	return .None
}

destroy :: proc(store: ^Store) {
	destroy_one_index(&store.by_subject)
	destroy_one_index(&store.by_predicate)
	destroy_one_index(&store.by_object)
	destroy_two_index(&store.by_subject_predicate)
	destroy_two_index(&store.by_subject_object)
	destroy_two_index(&store.by_predicate_object)
	delete(store.fact_ids)
	delete(store.facts)
	term.destroy(&store.dictionary)
	store^ = {}
}

term_count :: proc(store: ^Store) -> int { return term.count(&store.dictionary) }
fact_count :: proc(store: ^Store) -> int { return len(store.facts) }

// clone makes an independent owned copy while preserving stable Term_ID and
// Fact_ID order. destination must be uninitialized; on any error it is reset.
clone :: proc(source, destination: ^Store) -> Error_Code {
	if error := init(destination, options(source)); error != .None do return error
	for index in 0..<term_count(source) {
		id, value, found := term_at(source, index)
		if !found { destroy(destination); return .Invalid_Fact }
		cloned_id, error := intern_term(destination, value)
		if error != .None { destroy(destination); return error }
		if cloned_id != id { destroy(destination); return .Invalid_Fact }
	}
	for index in 0..<fact_count(source) {
		_, fact, origin, found := fact_at(source, index)
		if !found { destroy(destination); return .Invalid_Fact }
		added, error := insert(destination, fact, origin)
		if error != .None { destroy(destination); return error }
		if !added { destroy(destination); return .Invalid_Fact }
	}
	return .None
}

// commit_inferred inserts only facts whose source origin is Inferred. It is
// intended for a clone of destination after a successful transactional phase;
// both stores must therefore have identical term dictionaries and Term_IDs.
// Configured limits are checked by destination insertion and reported exactly.
commit_inferred :: proc(source, destination: ^Store) -> (added_count: int, error: Error_Code) {
	if term_count(source) != term_count(destination) do return 0, .Invalid_Fact
	for index in 0..<fact_count(source) {
		_, fact, origin, found := fact_at(source, index)
		if !found do return added_count, .Invalid_Fact
		if origin != .Inferred || contains(destination, fact) do continue
		added, insert_error := insert(destination, fact, .Inferred)
		if insert_error != .None do return added_count, insert_error
		if added do added_count += 1
	}
	return added_count, .None
}

// id_for_term performs a non-mutating lookup in the store-owned dictionary.
id_for_term :: proc(store: ^Store, value: rdf.Term) -> term.Term_ID {
	return term.id_for(&store.dictionary, value)
}

// intern_term admits a constant needed by a rule even when that term is not
// yet present in an asserted fact. The returned ID is owned by store.
intern_term :: proc(store: ^Store, value: rdf.Term) -> (term.Term_ID, Error_Code) {
	id, term_error := term.intern(&store.dictionary, value)
	#partial switch term_error {
	case .None: return id, .None
	case .Term_Limit: return term.INVALID_TERM_ID, .Term_Limit
	case .Lexical_Bytes_Limit: return term.INVALID_TERM_ID, .Lexical_Bytes_Limit
	case .Out_Of_Memory: return term.INVALID_TERM_ID, .Out_Of_Memory
	case: return term.INVALID_TERM_ID, .Invalid_Triple
	}
}

// intern_terms admits a batch of rule constants atomically with respect to the
// configured term and lexical-byte limits. ids must match values in length.
intern_terms :: proc(store: ^Store, values: []rdf.Term, ids: []term.Term_ID) -> Error_Code {
	term_error := term.intern_batch(&store.dictionary, values, ids)
	#partial switch term_error {
	case .None: return .None
	case .Term_Limit: return .Term_Limit
	case .Lexical_Bytes_Limit: return .Lexical_Bytes_Limit
	case .Out_Of_Memory: return .Out_Of_Memory
	case: return .Invalid_Triple
	}
}

// options returns the configured admission limits. It is useful to create a
// bounded working snapshot without exposing the store's representation.
options :: proc(store: ^Store) -> Options {
	return {
		max_terms = store.dictionary.max_terms,
		max_lexical_bytes = store.dictionary.max_lexical_bytes,
		max_facts = store.max_facts,
	}
}

// get_term returns a borrowed term owned by store.
get_term :: proc(store: ^Store, id: term.Term_ID) -> (rdf.Term, bool) {
	return term.get(&store.dictionary, id)
}

// term_at iterates owned terms in stable ID order. Returned strings are borrowed
// from store and remain valid until destroy.
term_at :: proc(store: ^Store, index: int) -> (id: term.Term_ID, value: rdf.Term, found: bool) {
	if index < 0 || index >= term.count(&store.dictionary) do return {}, {}, false
	id = term.Term_ID(index + 1)
	value, found = get_term(store, id)
	return id, value, found
}

// triple_for returns a borrowed RDF triple. It must not outlive the store.
triple_for :: proc(store: ^Store, id: Fact_ID) -> (rdf.Triple, bool) {
	index := int(id) - 1
	if id == INVALID_FACT_ID || index < 0 || index >= len(store.facts) do return {}, false
	fact := store.facts[index].fact
	subject, subject_ok := get_term(store, fact.subject)
	predicate, predicate_ok := get_term(store, fact.predicate)
	object, object_ok := get_term(store, fact.object)
	if !subject_ok || !predicate_ok || !object_ok do return {}, false
	return rdf.Triple{subject, predicate, object}, true
}

contains :: proc(store: ^Store, fact: Fact) -> bool {
	_, found := store.fact_ids[fact]
	return found
}

origin_for :: proc(store: ^Store, id: Fact_ID) -> (Origin, bool) {
	index := int(id) - 1
	if id == INVALID_FACT_ID || index < 0 || index >= len(store.facts) do return .Asserted, false
	return store.facts[index].origin, true
}

// fact_at provides deterministic insertion-order iteration without exposing
// the store's backing slice. The returned Fact refers only to stable Term_IDs.
fact_at :: proc(store: ^Store, index: int) -> (id: Fact_ID, fact: Fact, origin: Origin, found: bool) {
	if index < 0 || index >= len(store.facts) do return {}, {}, .Asserted, false
	record := store.facts[index]
	return Fact_ID(index + 1), record.fact, record.origin, true
}

// fact_for looks up a retained fact by ID without exposing the backing slice.
fact_for :: proc(store: ^Store, id: Fact_ID) -> (Fact, bool) {
	index := int(id) - 1
	if id == INVALID_FACT_ID || index < 0 || index >= len(store.facts) do return {}, false
	return store.facts[index].fact, true
}

// id_for_fact looks up a retained fact ID without mutation.
id_for_fact :: proc(store: ^Store, fact: Fact) -> Fact_ID {
	id, found := store.fact_ids[fact]
	if !found do return INVALID_FACT_ID
	return id
}

@(private) add_one_index :: proc(index: ^One_Index, key: term.Term_ID, id: Fact_ID) -> Error_Code {
	bucket_index, found := index.by_key[key]
	if !found {
		bucket_index = len(index.buckets)
		_, append_error := append(&index.buckets, Bucket{ids = make([dynamic]Fact_ID)})
		if append_error != nil do return .Out_Of_Memory
		index.by_key[key] = bucket_index
	}
	_, append_error := append(&index.buckets[bucket_index].ids, id)
	if append_error != nil do return .Out_Of_Memory
	return .None
}

@(private) add_two_index :: proc(index: ^Two_Index, key: Pair, id: Fact_ID) -> Error_Code {
	bucket_index, found := index.by_key[key]
	if !found {
		bucket_index = len(index.buckets)
		_, append_error := append(&index.buckets, Bucket{ids = make([dynamic]Fact_ID)})
		if append_error != nil do return .Out_Of_Memory
		index.by_key[key] = bucket_index
	}
	_, append_error := append(&index.buckets[bucket_index].ids, id)
	if append_error != nil do return .Out_Of_Memory
	return .None
}

@(private) valid_fact :: proc(store: ^Store, fact: Fact) -> bool {
	_, subject_ok := get_term(store, fact.subject)
	_, predicate_ok := get_term(store, fact.predicate)
	_, object_ok := get_term(store, fact.object)
	return subject_ok && predicate_ok && object_ok
}

// insert adds an interned fact. Equal facts are successful no-ops and retain
// their first Origin. Callers that have RDF terms should use insert_triple.
insert :: proc(store: ^Store, fact: Fact, origin: Origin) -> (added: bool, error: Error_Code) {
	if !valid_fact(store, fact) do return false, .Invalid_Fact
	if contains(store, fact) do return false, .None
	if store.max_facts > 0 && len(store.facts) >= store.max_facts do return false, .Fact_Limit
	record := Record{fact = fact, origin = origin}
	_, append_error := append(&store.facts, record)
	if append_error != nil do return false, .Out_Of_Memory
	id := Fact_ID(len(store.facts))
	store.fact_ids[fact] = id
	if error := add_one_index(&store.by_subject, fact.subject, id); error != .None do return false, error
	if error := add_one_index(&store.by_predicate, fact.predicate, id); error != .None do return false, error
	if error := add_one_index(&store.by_object, fact.object, id); error != .None do return false, error
	if error := add_two_index(&store.by_subject_predicate, {fact.subject, fact.predicate}, id); error != .None do return false, error
	if error := add_two_index(&store.by_subject_object, {fact.subject, fact.object}, id); error != .None do return false, error
	if error := add_two_index(&store.by_predicate_object, {fact.predicate, fact.object}, id); error != .None do return false, error
	return true, .None
}

// insert_triple validates RDF structure, copies/interns transient term strings,
// then inserts the fact. Limit failures do not partially admit terms or facts.
insert_triple :: proc(store: ^Store, triple: rdf.Triple, origin: Origin = .Asserted) -> (added: bool, error: Error_Code) {
	if rdf.validate_triple_structure(triple) != .None do return false, .Invalid_Triple
	known := [3]term.Term_ID{
		term.id_for(&store.dictionary, triple.subject),
		term.id_for(&store.dictionary, triple.predicate),
		term.id_for(&store.dictionary, triple.object),
	}
	all_known := known[0] != term.INVALID_TERM_ID && known[1] != term.INVALID_TERM_ID && known[2] != term.INVALID_TERM_ID
	if all_known && contains(store, Fact{known[0], known[1], known[2]}) do return false, .None
	if store.max_facts > 0 && len(store.facts) >= store.max_facts do return false, .Fact_Limit
	terms := [3]rdf.Term{triple.subject, triple.predicate, triple.object}
	ids := known
	term_error := term.intern_batch(&store.dictionary, terms[:], ids[:])
	if term_error != .None {
		#partial switch term_error {
		case .Term_Limit: return false, .Term_Limit
		case .Lexical_Bytes_Limit: return false, .Lexical_Bytes_Limit
		case .Out_Of_Memory: return false, .Out_Of_Memory
		case: return false, .Invalid_Triple
		}
	}
	return insert(store, Fact{ids[0], ids[1], ids[2]}, origin)
}

@(private) matches :: proc(fact: Fact, pattern: Pattern) -> bool {
	return (pattern.subject == term.INVALID_TERM_ID || pattern.subject == fact.subject) &&
		(pattern.predicate == term.INVALID_TERM_ID || pattern.predicate == fact.predicate) &&
		(pattern.object == term.INVALID_TERM_ID || pattern.object == fact.object)
}

@(private) visit :: proc(store: ^Store, id: Fact_ID, pattern: Pattern, sink: Match_Sink, user_data: rawptr, result: ^Match_Result) -> bool {
	if id == INVALID_FACT_ID do return true
	record := store.facts[int(id) - 1]
	if !matches(record.fact, pattern) do return true
	result.matched += 1
	if !sink(id, record.fact, record.origin, user_data) {
		result.stopped = true
		return false
	}
	return true
}

@(private) visit_bucket :: proc(store: ^Store, bucket: Bucket, pattern: Pattern, sink: Match_Sink, user_data: rawptr, result: ^Match_Result) {
	for id in bucket.ids {
		if !visit(store, id, pattern, sink, user_data, result) do return
	}
}

// match scans facts satisfying a constant/wildcard pattern. It uses the fact
// lookup for an exact pattern, a two-position index when possible, then a
// one-position index; a nil sink is an explicit error.
match :: proc(store: ^Store, pattern: Pattern, sink: Match_Sink, user_data: rawptr = nil) -> Match_Result {
	result: Match_Result
	if sink == nil { result.error = .Missing_Sink; return result }
	s, p, o := pattern.subject, pattern.predicate, pattern.object
	if s != term.INVALID_TERM_ID && p != term.INVALID_TERM_ID && o != term.INVALID_TERM_ID {
		if id, found := store.fact_ids[Fact{s, p, o}]; found do _ = visit(store, id, pattern, sink, user_data, &result)
		return result
	}
	if s != term.INVALID_TERM_ID && p != term.INVALID_TERM_ID {
		if index, found := store.by_subject_predicate.by_key[Pair{s, p}]; found do visit_bucket(store, store.by_subject_predicate.buckets[index], pattern, sink, user_data, &result)
		return result
	}
	if s != term.INVALID_TERM_ID && o != term.INVALID_TERM_ID {
		if index, found := store.by_subject_object.by_key[Pair{s, o}]; found do visit_bucket(store, store.by_subject_object.buckets[index], pattern, sink, user_data, &result)
		return result
	}
	if p != term.INVALID_TERM_ID && o != term.INVALID_TERM_ID {
		if index, found := store.by_predicate_object.by_key[Pair{p, o}]; found do visit_bucket(store, store.by_predicate_object.buckets[index], pattern, sink, user_data, &result)
		return result
	}
	if s != term.INVALID_TERM_ID {
		if index, found := store.by_subject.by_key[s]; found do visit_bucket(store, store.by_subject.buckets[index], pattern, sink, user_data, &result)
		return result
	}
	if p != term.INVALID_TERM_ID {
		if index, found := store.by_predicate.by_key[p]; found do visit_bucket(store, store.by_predicate.buckets[index], pattern, sink, user_data, &result)
		return result
	}
	if o != term.INVALID_TERM_ID {
		if index, found := store.by_object.by_key[o]; found do visit_bucket(store, store.by_object.buckets[index], pattern, sink, user_data, &result)
		return result
	}
	for record, index in store.facts {
		if !visit(store, Fact_ID(index + 1), pattern, sink, user_data, &result) do break
		_ = record
	}
	return result
}
