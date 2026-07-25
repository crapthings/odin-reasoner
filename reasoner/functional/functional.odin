// Package functional parses a deliberately bounded OWL 2 Functional Syntax
// document and maps supported axioms to RDF triples. It is an input adapter;
// materialization remains owned by the reasoner profiles.
package functional

import "core:strings"
import "core:strconv"
import rdf "odin-rdf:rdf"

Error_Code :: enum {
	None,
	Invalid_Syntax,
	Unknown_Prefix,
	Unsupported_Axiom,
	Sink_Stopped,
	Out_Of_Memory,
}

Result :: struct { code: Error_Code }

Sink :: proc(triple: rdf.Triple, user_data: rawptr) -> bool

@(private) State :: struct {
	input:     string,
	position:  int,
	prefixes:  map[string]string,
	owned:     [dynamic]string,
	sink:      Sink,
	user_data: rawptr,
	scope:     rdf.Blank_Node_Scope,
	generated: int,
}

@(private) destroy :: proc(state: ^State) {
	for value in state.owned do delete(value)
	delete(state.owned)
	if state.prefixes != nil do delete(state.prefixes)
}

@(private) is_space :: proc(value: u8) -> bool {
	return value == ' ' || value == '\t' || value == '\n' || value == '\r'
}

@(private) skip_space :: proc(state: ^State) {
	for state.position < len(state.input) && is_space(state.input[state.position]) do state.position += 1
}

@(private) read_word :: proc(state: ^State) -> string {
	skip_space(state)
	start := state.position
	for state.position < len(state.input) {
		value := state.input[state.position]
		if is_space(value) || value == '(' || value == ')' || value == '=' || value == '<' || value == '>' do break
		state.position += 1
	}
	return state.input[start:state.position]
}

@(private) consume :: proc(state: ^State, value: u8) -> bool {
	skip_space(state)
	if state.position >= len(state.input) || state.input[state.position] != value do return false
	state.position += 1
	return true
}

@(private) read_iri :: proc(state: ^State) -> string {
	skip_space(state)
	if state.position >= len(state.input) || state.input[state.position] != '<' do return ""
	state.position += 1
	start := state.position
	for state.position < len(state.input) && state.input[state.position] != '>' do state.position += 1
	if state.position >= len(state.input) do return ""
	result := state.input[start:state.position]
	state.position += 1
	return result
}

@(private) own_concat :: proc(state: ^State, left, right: string) -> (string, bool) {
	value, error := strings.concatenate([]string{left, right})
	if error != nil do return "", false
	_, append_error := append(&state.owned, value)
	if append_error != nil { delete(value); return "", false }
	return value, true
}

@(private) individual :: proc(state: ^State) -> (rdf.Term, Error_Code) {
	skip_space(state)
	if state.position < len(state.input) && state.input[state.position] == '<' {
		iri := read_iri(state)
		if len(iri) == 0 do return {}, .Invalid_Syntax
		return rdf.iri(iri), .None
	}
	name := read_word(state)
	if len(name) == 0 do return {}, .Invalid_Syntax
	colon := strings.index_byte(name, ':')
	if colon < 0 do return {}, .Invalid_Syntax
	prefix, local := name[:colon], name[colon + 1:]
	base, found := state.prefixes[prefix]
	if !found do return {}, .Unknown_Prefix
	iri, ok := own_concat(state, base, local)
	if !ok do return {}, .Out_Of_Memory
	return rdf.iri(iri), .None
}

@(private) emit :: proc(state: ^State, triple: rdf.Triple) -> Error_Code {
	if !state.sink(triple, state.user_data) do return .Sink_Stopped
	return .None
}

@(private) fresh_blank :: proc(state: ^State) -> rdf.Term {
	state.generated += 1
	buffer: [32]byte
	label, ok := own_concat(state, "functional-", strconv.write_int(buffer[:], i64(state.generated), 10))
	if !ok do return {}
	return rdf.blank_node(label, state.scope)
}

@(private) parse_prefix :: proc(state: ^State) -> Error_Code {
	if !consume(state, '(') do return .Invalid_Syntax
	prefix := read_word(state)
	if len(prefix) == 0 || prefix[len(prefix) - 1] != ':' || !consume(state, '=') do return .Invalid_Syntax
	iri := read_iri(state)
	if len(iri) == 0 || !consume(state, ')') do return .Invalid_Syntax
	state.prefixes[prefix[:len(prefix) - 1]] = iri
	return .None
}

@(private) parse_individuals :: proc(state: ^State, values: ^[dynamic]rdf.Term) -> Error_Code {
	for {
		skip_space(state)
		if state.position >= len(state.input) do return .Invalid_Syntax
		if state.input[state.position] == ')' { state.position += 1; break }
		value, error := individual(state)
		if error != .None do return error
		_, append_error := append(values, value)
		if append_error != nil do return .Out_Of_Memory
	}
	if len(values^) < 2 do return .Invalid_Syntax
	return .None
}

@(private) map_same_individual :: proc(state: ^State, values: []rdf.Term) -> Error_Code {
	same_as := rdf.iri("http://www.w3.org/2002/07/owl#sameAs")
	for index in 0..<len(values) - 1 {
		if error := emit(state, {values[index], same_as, values[index + 1]}); error != .None do return error
	}
	return .None
}

@(private) map_different_individuals :: proc(state: ^State, values: []rdf.Term) -> Error_Code {
	if len(values) == 2 do return emit(state, {values[0], rdf.iri("http://www.w3.org/2002/07/owl#differentFrom"), values[1]})
	all_different := fresh_blank(state)
	members_head := fresh_blank(state)
	if all_different.kind != .Blank_Node || members_head.kind != .Blank_Node do return .Out_Of_Memory
	if error := emit(state, {all_different, rdf.iri("http://www.w3.org/1999/02/22-rdf-syntax-ns#type"), rdf.iri("http://www.w3.org/2002/07/owl#AllDifferent")}); error != .None do return error
	if error := emit(state, {all_different, rdf.iri("http://www.w3.org/2002/07/owl#members"), members_head}); error != .None do return error
	current := members_head
	for index in 0..<len(values) {
		if error := emit(state, {current, rdf.iri("http://www.w3.org/1999/02/22-rdf-syntax-ns#first"), values[index]}); error != .None do return error
		next := rdf.iri("http://www.w3.org/1999/02/22-rdf-syntax-ns#nil")
		if index + 1 < len(values) {
			next = fresh_blank(state)
			if next.kind != .Blank_Node do return .Out_Of_Memory
		}
		if error := emit(state, {current, rdf.iri("http://www.w3.org/1999/02/22-rdf-syntax-ns#rest"), next}); error != .None do return error
		current = next
	}
	return .None
}

// parse maps Prefix declarations plus SameIndividual and DifferentIndividuals
// axioms inside one Ontology. All other Functional Syntax constructs return an
// explicit Unsupported_Axiom result without emitting a partial axiom.
parse :: proc(input: string, sink: Sink, user_data: rawptr = nil) -> Result {
	if sink == nil do return {.Sink_Stopped}
	state := State{input = input, prefixes = make(map[string]string), sink = sink, user_data = user_data, scope = rdf.new_blank_node_scope()}
	defer destroy(&state)
	for {
		word := read_word(&state)
		if word == "Prefix" {
			if error := parse_prefix(&state); error != .None do return {error}
			continue
		}
		if word != "Ontology" || !consume(&state, '(') do return {.Invalid_Syntax}
		ontology := fresh_blank(&state)
		if ontology.kind != .Blank_Node do return {.Out_Of_Memory}
		if error := emit(&state, {ontology, rdf.iri("http://www.w3.org/1999/02/22-rdf-syntax-ns#type"), rdf.iri("http://www.w3.org/2002/07/owl#Ontology")}); error != .None do return {error}
		break
	}
	for {
		skip_space(&state)
		if state.position >= len(state.input) do return {.Invalid_Syntax}
		if state.input[state.position] == ')' {
			state.position += 1
			skip_space(&state)
			return state.position == len(state.input) ? Result{} : Result{.Invalid_Syntax}
		}
		axiom := read_word(&state)
		if !consume(&state, '(') do return {.Invalid_Syntax}
		values := make([dynamic]rdf.Term)
		error := parse_individuals(&state, &values)
		if error == .None {
			switch axiom {
			case "SameIndividual": error = map_same_individual(&state, values[:])
			case "DifferentIndividuals": error = map_different_individuals(&state, values[:])
			case: error = .Unsupported_Axiom
			}
		}
		delete(values)
		if error != .None do return {error}
	}
}
