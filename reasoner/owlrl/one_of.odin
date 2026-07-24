package owlrl

import rdf "odin-rdf:rdf"
import rule "../rule"
import store "../store"

// One_Of_Options bounds the dynamic RDF-list phase. max_rounds and
// max_derivations apply across alternating static-rule and oneOf phases; zero
// disables each bound. max_list_items applies to each decoded collection.
One_Of_Options :: struct {
	max_rounds:      int,
	max_derivations: int,
	max_list_items:  int,
}

One_Of_Error_Code :: enum {
	None,
	Invalid_Option,
	Rule_Error,
	List_Error,
	Store_Error,
}

One_Of_Result :: struct {
	error:          One_Of_Error_Code,
	rule_error:     rule.Error_Code,
	list_error:     List_Error_Code,
	store_error:    store.Error_Code,
	rounds:         int,
	inferred_facts: int,
}

@(private) one_of_error_from_store :: proc(error: store.Error_Code) -> One_Of_Error_Code {
	if error == .None do return .None
	return .Store_Error
}

// remaining is -1 when the global derivation limit is disabled; zero therefore
// correctly means that this phase may add no further facts.
@(private) emit_one_of :: proc(profile: ^Profile, target: ^store.Store, options: One_Of_Options, remaining: int) -> (added_count: int, error: One_Of_Error_Code, list_error: List_Error_Code, store_error: store.Error_Code) {
	list: List
	init_list(&list)
	defer destroy_list(&list)
	for index in 0..<store.fact_count(target) {
		_, declaration, _, found := store.fact_at(target, index)
		if !found do return added_count, .Store_Error, .None, .Invalid_Fact
		if declaration.predicate != profile.terms.one_of do continue
		if list_error = read_list(profile, target, declaration.object, &list, {max_items = options.max_list_items}); list_error != .None do return added_count, .List_Error, list_error, .None
		for item_index in 0..<list_count(&list) {
			item, item_found := list_item_at(&list, item_index)
			if !item_found do return added_count, .Store_Error, .None, .Invalid_Fact
			subject, subject_ok := store.get_term(target, item)
			predicate, predicate_ok := store.get_term(target, profile.terms.rdf_type)
			object, object_ok := store.get_term(target, declaration.subject)
			if !subject_ok || !predicate_ok || !object_ok do return added_count, .Store_Error, .None, .Invalid_Fact
			if rdf.validate_triple_structure({subject, predicate, object}) != .None do continue
			fact := store.Fact{subject = item, predicate = profile.terms.rdf_type, object = declaration.subject}
			if store.contains(target, fact) do continue
			if remaining >= 0 && added_count >= remaining do return added_count, .Rule_Error, .None, .None
			added, insert_error := store.insert(target, fact, .Inferred)
			if insert_error != .None do return added_count, one_of_error_from_store(insert_error), .None, insert_error
			if added do added_count += 1
		}
	}
	return added_count, .None, .None, .None
}

// materialize_one_of alternates the static OWL/RDFS rule table with the W3C
// owl:oneOf list rule until joint fixpoint. All work happens in a cloned store;
// list errors and configured limits leave target unchanged. Dynamic oneOf facts
// are committed as inferred facts on success; this initial dynamic phase does
// not expose per-fact rule provenance through Materializer.
materialize_one_of :: proc(profile: ^Profile, target: ^store.Store, options: One_Of_Options = {}) -> One_Of_Result {
	result: One_Of_Result
	if options.max_rounds < 0 || options.max_derivations < 0 || options.max_list_items < 0 {
		result.error = .Invalid_Option
		return result
	}
	if !profile.initialized { result.error = .Rule_Error; result.rule_error = .Invalid_Rule; return result }
	work: store.Store
	if clone_error := store.clone(target, &work); clone_error != .None {
		result.error = .Store_Error
		result.store_error = clone_error
		return result
	}
	defer store.destroy(&work)
	for {
		if options.max_rounds != 0 && result.rounds >= options.max_rounds { result.error = .Rule_Error; result.rule_error = .Max_Rounds; return result }
		remaining := -1
		if options.max_derivations != 0 {
			remaining = options.max_derivations - result.inferred_facts
			if remaining <= 0 { result.error = .Rule_Error; result.rule_error = .Max_Derivations; return result }
		}
		static_limit := 0
		if remaining >= 0 do static_limit = remaining
		temporary: rule.Materializer
		rule.init(&temporary)
		static := rule.materialize(&temporary, &work, profile.rules[:], {max_derivations = static_limit})
		rule.destroy(&temporary)
		if static.error != .None {
			result.error = .Rule_Error
			result.rule_error = static.error
			result.store_error = static.store_error
			return result
		}
		result.inferred_facts += static.inferred_facts
		remaining = -1
		if options.max_derivations != 0 do remaining = options.max_derivations - result.inferred_facts
		dynamic_added, dynamic_error, list_error, store_error := emit_one_of(profile, &work, options, remaining)
		if dynamic_error != .None {
			result.error = dynamic_error
			result.list_error = list_error
			result.store_error = store_error
			if dynamic_error == .Rule_Error do result.rule_error = .Max_Derivations
			return result
		}
		result.inferred_facts += dynamic_added
		result.rounds += 1
		if static.inferred_facts == 0 && dynamic_added == 0 do break
	}
	_, commit_error := store.commit_inferred(&work, target)
	if commit_error != .None {
		result.error = .Store_Error
		result.store_error = commit_error
		result.inferred_facts = 0
		result.rounds = 0
		return result
	}
	return result
}
