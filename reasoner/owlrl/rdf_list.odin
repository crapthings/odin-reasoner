package owlrl

import store "../store"
import term "../term"

// List_Options bounds one decoded RDF collection. A zero limit disables the
// item bound; malformed and cyclic lists still terminate deterministically.
// generalized_heads accepts sameAs-equivalent first/rest values produced by a
// generalized closure while retaining strict malformed-list rejection by
// default.
List_Options :: struct {
	max_items:         int,
	generalized_heads: bool,
}

List_Error_Code :: enum {
	None,
	Invalid_Option,
	Invalid_Profile,
	Invalid_Head,
	Missing_First,
	Multiple_First,
	Missing_Rest,
	Multiple_Rest,
	Cycle,
	Item_Limit,
	Out_Of_Memory,
}

list_error_message :: proc(code: List_Error_Code) -> string {
	switch code {
	case .None:            return "no list error"
	case .Invalid_Option:  return "list item limit must not be negative"
	case .Invalid_Profile: return "OWL RL profile is not initialized"
	case .Invalid_Head:    return "RDF list head is not an interned term"
	case .Missing_First:   return "RDF list node has no rdf:first"
	case .Multiple_First:  return "RDF list node has multiple rdf:first values"
	case .Missing_Rest:    return "RDF list node has no rdf:rest"
	case .Multiple_Rest:   return "RDF list node has multiple rdf:rest values"
	case .Cycle:           return "RDF list contains an rdf:rest cycle"
	case .Item_Limit:      return "RDF list item limit reached"
	case .Out_Of_Memory:   return "out of memory while decoding RDF list"
	}
	return "unknown RDF list error"
}

// List owns decoded terms and the RDF:first/rest fact IDs that witness them
// until destroy_list. A failed read clears every slice so no partial list or
// provenance support escapes.
List :: struct {
	items:       [dynamic]term.Term_ID,
	first_facts: [dynamic]store.Fact_ID,
	rest_facts:  [dynamic]store.Fact_ID,
}

init_list :: proc(list: ^List) {
	list^ = List{
		items = make([dynamic]term.Term_ID),
		first_facts = make([dynamic]store.Fact_ID),
		rest_facts = make([dynamic]store.Fact_ID),
	}
}

destroy_list :: proc(list: ^List) {
	delete(list.items)
	delete(list.first_facts)
	delete(list.rest_facts)
	list^ = {}
}

clear_list :: proc(list: ^List) {
	clear(&list.items)
	clear(&list.first_facts)
	clear(&list.rest_facts)
}

list_count :: proc(list: ^List) -> int { return len(list.items) }

list_item_at :: proc(list: ^List, index: int) -> (term.Term_ID, bool) {
	if index < 0 || index >= len(list.items) do return term.INVALID_TERM_ID, false
	return list.items[index], true
}

list_first_fact_at :: proc(list: ^List, index: int) -> (store.Fact_ID, bool) {
	if index < 0 || index >= len(list.first_facts) do return store.INVALID_FACT_ID, false
	return list.first_facts[index], true
}

list_rest_fact_at :: proc(list: ^List, index: int) -> (store.Fact_ID, bool) {
	if index < 0 || index >= len(list.rest_facts) do return store.INVALID_FACT_ID, false
	return list.rest_facts[index], true
}

@(private) objects_are_same_as :: proc(profile: ^Profile, target: ^store.Store, left, right: term.Term_ID) -> bool {
	if left == right do return true
	return store.contains(target, {subject = left, predicate = profile.terms.same_as, object = right})
}

@(private) unique_object :: proc(profile: ^Profile, target: ^store.Store, subject, predicate: term.Term_ID, generalized_heads: bool) -> (term.Term_ID, List_Error_Code) {
	found := false
	value := term.INVALID_TERM_ID
	for index in 0..<store.fact_count(target) {
		_, fact, _, fact_found := store.fact_at(target, index)
		if !fact_found do return term.INVALID_TERM_ID, .Out_Of_Memory
		if fact.subject != subject || fact.predicate != predicate do continue
		if !found {
			found = true
			value = fact.object
			continue
		}
		if !generalized_heads || !objects_are_same_as(profile, target, value, fact.object) do return term.INVALID_TERM_ID, .Multiple_First
	}
	if !found {
		if predicate == term.INVALID_TERM_ID do return term.INVALID_TERM_ID, .Out_Of_Memory
		return term.INVALID_TERM_ID, .Missing_First
	}
	return value, .None
}

@(private) first_object :: proc(target: ^store.Store, subject: term.Term_ID, profile: ^Profile, generalized_heads: bool) -> (term.Term_ID, List_Error_Code) {
	value, error := unique_object(profile, target, subject, profile.terms.rdf_first, generalized_heads)
	return value, error
}

@(private) rest_object :: proc(target: ^store.Store, subject: term.Term_ID, profile: ^Profile, generalized_heads: bool) -> (term.Term_ID, List_Error_Code) {
	value, error := unique_object(profile, target, subject, profile.terms.rdf_rest, generalized_heads)
	if error == .Missing_First do error = .Missing_Rest
	if error == .Multiple_First do error = .Multiple_Rest
	return value, error
}

// read_list decodes one well-formed RDF collection from head through rdf:nil.
// It is non-mutating and clears output on every error, including configured
// item limits, malformed branching, and cycles.
read_list :: proc(profile: ^Profile, target: ^store.Store, head: term.Term_ID, list: ^List, options: List_Options = {}) -> List_Error_Code {
	if options.max_items < 0 do return .Invalid_Option
	if !profile.initialized do return .Invalid_Profile
	if head == term.INVALID_TERM_ID do return .Invalid_Head
	clear_list(list)
	seen := make(map[term.Term_ID]bool)
	defer delete(seen)
	current := head
	for {
		if current == profile.terms.rdf_nil do return .None
		if seen[current] {
			clear_list(list)
			return .Cycle
		}
		seen[current] = true
		item, first_error := first_object(target, current, profile, options.generalized_heads)
		if first_error != .None {
			clear_list(list)
			return first_error
		}
		next, rest_error := rest_object(target, current, profile, options.generalized_heads)
		if rest_error != .None {
			clear_list(list)
			return rest_error
		}
		if options.max_items != 0 && len(list.items) >= options.max_items {
			clear_list(list)
			return .Item_Limit
		}
		_, append_error := append(&list.items, item)
		if append_error != nil {
			clear_list(list)
			return .Out_Of_Memory
		}
		first_id := store.id_for_fact(target, {subject = current, predicate = profile.terms.rdf_first, object = item})
		rest_id := store.id_for_fact(target, {subject = current, predicate = profile.terms.rdf_rest, object = next})
		if first_id == store.INVALID_FACT_ID || rest_id == store.INVALID_FACT_ID {
			clear_list(list)
			return .Out_Of_Memory
		}
		_, append_error = append(&list.first_facts, first_id)
		if append_error != nil {
			clear_list(list)
			return .Out_Of_Memory
		}
		_, append_error = append(&list.rest_facts, rest_id)
		if append_error != nil {
			clear_list(list)
			return .Out_Of_Memory
		}
		current = next
	}
}
