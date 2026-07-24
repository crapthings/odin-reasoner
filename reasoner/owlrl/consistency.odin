package owlrl

import rdf "odin-rdf:rdf"
import rule "../rule"
import store "../store"
import term "../term"

// Consistency_Options bounds retained conflict evidence. A zero limit disables
// the bound. A limit error clears the report so callers never mistake a prefix
// for a complete consistency result.
Consistency_Options :: struct { max_violations: int }

Consistency_Error_Code :: enum {
	None,
	Invalid_Option,
	Invalid_Profile,
	List_Error,
	Violation_Limit,
	Out_Of_Memory,
}

consistency_error_message :: proc(code: Consistency_Error_Code) -> string {
	switch code {
	case .None:            return "no consistency error"
	case .Invalid_Option:  return "consistency limits must not be negative"
	case .Invalid_Profile: return "OWL RL profile is not initialized"
	case .List_Error:      return "malformed RDF list in an OWL consistency rule"
	case .Violation_Limit: return "consistency violation limit reached"
	case .Out_Of_Memory:   return "out of memory while recording consistency evidence"
	}
	return "unknown OWL RL consistency error"
}

// Violation_Kind identifies the implemented OWL 2 RL rules whose conclusion is
// false. Datatype_Not_Type is available on the generalized datatype path.
Violation_Kind :: enum {
	Same_As_Different_From,
	Disjoint_Classes,
	Complement_Classes,
	All_Disjoint_Classes,
	All_Disjoint_Properties,
	Negative_Property_Assertion,
	All_Different,
	Nothing_Instance,
	Disjoint_Properties,
	Irreflexive_Property,
	Asymmetric_Property,
	Max_Cardinality_Zero,
	Max_Qualified_Cardinality_Zero,
	Datatype_Not_Type,
}

@(private) is_owl_rl_datatype_id :: proc(profile: ^Profile, candidate: term.Term_ID) -> bool {
	for datatype in profile.terms.owl_rl_datatypes {
		if datatype == candidate do return true
	}
	return false
}

// check_datatype_not_type implements dt-not-type for a generalized rdf:type
// fact whose subject is a literal. The fact itself is its complete witness: the
// value-space failure is determined by odin-rdf's exact No result.
@(private) check_datatype_not_type :: proc(state: ^Check_State, type_fact_id: store.Fact_ID, fact: store.Fact) {
	if !is_owl_rl_datatype_id(state.profile, fact.object) do return
	literal, literal_found := store.get_term(state.target, fact.subject)
	datatype, datatype_found := store.get_term(state.target, fact.object)
	if !literal_found || !datatype_found { state.error = .Out_Of_Memory; return }
	if literal.kind != .Literal do return
	if rdf.owl_rl_literal_value_membership(literal, datatype.value) == .No do _ = add_violation(state, .Datatype_Not_Type, []store.Fact_ID{type_fact_id})
}

// Violation stores up to six closure Fact_IDs that witness one contradiction.
// The support array is sorted and only its first support_count entries are valid.
Violation :: struct {
	kind:          Violation_Kind,
	supports:      [6]store.Fact_ID,
	support_count: int,
}

// Report owns its violation slice until destroy_report. Violation views borrow
// from it and remain valid until clear_report, the next check, or destroy_report.
Report :: struct { violations: [dynamic]Violation }

init_report :: proc(report: ^Report) { report^ = Report{violations = make([dynamic]Violation)} }

destroy_report :: proc(report: ^Report) {
	delete(report.violations)
	report^ = {}
}

clear_report :: proc(report: ^Report) { clear(&report.violations) }

violation_count :: proc(report: ^Report) -> int { return len(report.violations) }

violation_at :: proc(report: ^Report, index: int) -> (Violation, bool) {
	if index < 0 || index >= len(report.violations) do return {}, false
	return report.violations[index], true
}

@(private) Violation_Key :: struct {
	kind:          Violation_Kind,
	supports:      [6]store.Fact_ID,
	support_count: int,
}

@(private) Check_State :: struct {
	profile: ^Profile,
	target:  ^store.Store,
	report:  ^Report,
	options: Consistency_Options,
	seen:    map[Violation_Key]bool,
	error:   Consistency_Error_Code,
}

@(private) order_supports :: proc(violation: ^Violation) {
	for right in 1..<violation.support_count {
		left := right
		for left > 0 && violation.supports[left] < violation.supports[left - 1] {
			violation.supports[left], violation.supports[left - 1] = violation.supports[left - 1], violation.supports[left]
			left -= 1
		}
	}
}

@(private) add_violation :: proc(state: ^Check_State, kind: Violation_Kind, supports: []store.Fact_ID) -> bool {
	if state.error != .None do return false
	violation := Violation{kind = kind, support_count = len(supports)}
	for index in 0..<len(supports) do violation.supports[index] = supports[index]
	order_supports(&violation)
	key := Violation_Key{kind = violation.kind, supports = violation.supports, support_count = violation.support_count}
	if state.seen[key] do return true
	if state.options.max_violations != 0 && len(state.report.violations) >= state.options.max_violations {
		state.error = .Violation_Limit
		return false
	}
	_, append_error := append(&state.report.violations, violation)
	if append_error != nil {
		state.error = .Out_Of_Memory
		return false
	}
	state.seen[key] = true
	return true
}

@(private) Class_State :: struct {
	base:         ^Check_State,
	rule_fact_id: store.Fact_ID,
	other_class:  term.Term_ID,
	kind:         Violation_Kind,
}

@(private) class_sink :: proc(id: store.Fact_ID, fact: store.Fact, _: store.Origin, user_data: rawptr) -> bool {
	state := cast(^Class_State)user_data
	other := store.id_for_fact(state.base.target, {subject = fact.subject, predicate = state.base.profile.terms.rdf_type, object = state.other_class})
	if other == store.INVALID_FACT_ID do return true
	return add_violation(state.base, state.kind, []store.Fact_ID{state.rule_fact_id, id, other})
}

@(private) All_Disjoint_Pair_State :: struct {
	base:               ^Check_State,
	group_type_fact_id: store.Fact_ID,
	members_fact_id:    store.Fact_ID,
	other_class:        term.Term_ID,
}

@(private) all_disjoint_pair_sink :: proc(id: store.Fact_ID, fact: store.Fact, _: store.Origin, user_data: rawptr) -> bool {
	state := cast(^All_Disjoint_Pair_State)user_data
	other := store.id_for_fact(state.base.target, {subject = fact.subject, predicate = state.base.profile.terms.rdf_type, object = state.other_class})
	if other == store.INVALID_FACT_ID do return true
	return add_violation(state.base, .All_Disjoint_Classes, []store.Fact_ID{state.group_type_fact_id, state.members_fact_id, id, other})
}

@(private) All_Disjoint_Members_State :: struct {
	base:               ^Check_State,
	group_type_fact_id: store.Fact_ID,
}

@(private) all_disjoint_members_sink :: proc(id: store.Fact_ID, fact: store.Fact, _: store.Origin, user_data: rawptr) -> bool {
	state := cast(^All_Disjoint_Members_State)user_data
	list: List
	init_list(&list)
	defer destroy_list(&list)
	if read_list(state.base.profile, state.base.target, fact.object, &list) != .None {
		state.base.error = .List_Error
		return false
	}
	for left_index in 0..<list_count(&list) {
		left_class, _ := list_item_at(&list, left_index)
		for right_index in left_index + 1..<list_count(&list) {
			right_class, _ := list_item_at(&list, right_index)
			pair_state := All_Disjoint_Pair_State{
				base = state.base,
				group_type_fact_id = state.group_type_fact_id,
				members_fact_id = id,
				other_class = right_class,
			}
			_ = store.match(state.base.target, {predicate = state.base.profile.terms.rdf_type, object = left_class}, all_disjoint_pair_sink, &pair_state)
			if state.base.error != .None do return false
		}
	}
	return true
}

@(private) All_Disjoint_Property_Pair_State :: struct {
	base:               ^Check_State,
	group_type_fact_id: store.Fact_ID,
	members_fact_id:    store.Fact_ID,
	other_property:     term.Term_ID,
}

@(private) all_disjoint_property_pair_sink :: proc(id: store.Fact_ID, fact: store.Fact, _: store.Origin, user_data: rawptr) -> bool {
	state := cast(^All_Disjoint_Property_Pair_State)user_data
	other := store.id_for_fact(state.base.target, {subject = fact.subject, predicate = state.other_property, object = fact.object})
	if other == store.INVALID_FACT_ID do return true
	return add_violation(state.base, .All_Disjoint_Properties, []store.Fact_ID{state.group_type_fact_id, state.members_fact_id, id, other})
}

@(private) All_Disjoint_Properties_Members_State :: struct {
	base:               ^Check_State,
	group_type_fact_id: store.Fact_ID,
}

@(private) all_disjoint_properties_members_sink :: proc(id: store.Fact_ID, fact: store.Fact, _: store.Origin, user_data: rawptr) -> bool {
	state := cast(^All_Disjoint_Properties_Members_State)user_data
	list: List
	init_list(&list)
	defer destroy_list(&list)
	if read_list(state.base.profile, state.base.target, fact.object, &list) != .None {
		state.base.error = .List_Error
		return false
	}
	for left_index in 0..<list_count(&list) {
		left_property, _ := list_item_at(&list, left_index)
		for right_index in left_index + 1..<list_count(&list) {
			right_property, _ := list_item_at(&list, right_index)
			pair_state := All_Disjoint_Property_Pair_State{
				base = state.base,
				group_type_fact_id = state.group_type_fact_id,
				members_fact_id = id,
				other_property = right_property,
			}
			_ = store.match(state.base.target, {predicate = left_property}, all_disjoint_property_pair_sink, &pair_state)
			if state.base.error != .None do return false
		}
	}
	return true
}

@(private) All_Different_Members_State :: struct {
	base:               ^Check_State,
	group_type_fact_id: store.Fact_ID,
}

@(private) all_different_members_sink :: proc(id: store.Fact_ID, fact: store.Fact, _: store.Origin, user_data: rawptr) -> bool {
	state := cast(^All_Different_Members_State)user_data
	list: List
	init_list(&list)
	defer destroy_list(&list)
	if read_list(state.base.profile, state.base.target, fact.object, &list) != .None {
		state.base.error = .List_Error
		return false
	}
	for left_index in 0..<list_count(&list) {
		left, _ := list_item_at(&list, left_index)
		for right_index in left_index + 1..<list_count(&list) {
			right, _ := list_item_at(&list, right_index)
			same := store.id_for_fact(state.base.target, {subject = left, predicate = state.base.profile.terms.same_as, object = right})
			if same != store.INVALID_FACT_ID && !add_violation(state.base, .All_Different, []store.Fact_ID{state.group_type_fact_id, id, same}) do return false
		}
	}
	return true
}

@(private) Property_State :: struct {
	base:             ^Check_State,
	rule_fact_id:     store.Fact_ID,
	other_predicate:  term.Term_ID,
}

@(private) property_sink :: proc(id: store.Fact_ID, fact: store.Fact, _: store.Origin, user_data: rawptr) -> bool {
	state := cast(^Property_State)user_data
	other := store.id_for_fact(state.base.target, {subject = fact.subject, predicate = state.other_predicate, object = fact.object})
	if other == store.INVALID_FACT_ID do return true
	return add_violation(state.base, .Disjoint_Properties, []store.Fact_ID{state.rule_fact_id, id, other})
}

@(private) Irreflexive_State :: struct {
	base:         ^Check_State,
	type_fact_id: store.Fact_ID,
}

@(private) irreflexive_sink :: proc(id: store.Fact_ID, fact: store.Fact, _: store.Origin, user_data: rawptr) -> bool {
	state := cast(^Irreflexive_State)user_data
	if fact.subject != fact.object do return true
	return add_violation(state.base, .Irreflexive_Property, []store.Fact_ID{state.type_fact_id, id})
}

@(private) Asymmetric_State :: struct {
	base:         ^Check_State,
	type_fact_id: store.Fact_ID,
}

@(private) asymmetric_sink :: proc(id: store.Fact_ID, fact: store.Fact, _: store.Origin, user_data: rawptr) -> bool {
	state := cast(^Asymmetric_State)user_data
	other := store.id_for_fact(state.base.target, {subject = fact.object, predicate = fact.predicate, object = fact.subject})
	if other == store.INVALID_FACT_ID do return true
	return add_violation(state.base, .Asymmetric_Property, []store.Fact_ID{state.type_fact_id, id, other})
}

@(private) check_negative_property_assertion :: proc(state: ^Check_State, type_fact_id: store.Fact_ID, assertion: term.Term_ID) {
	for source_index in 0..<store.fact_count(state.target) {
		source_id, source_fact, _, source_found := store.fact_at(state.target, source_index)
		if !source_found { state.error = .Out_Of_Memory; return }
		if source_fact.subject != assertion || source_fact.predicate != state.profile.terms.source_individual do continue
		for property_index in 0..<store.fact_count(state.target) {
			property_id, property_fact, _, property_found := store.fact_at(state.target, property_index)
			if !property_found { state.error = .Out_Of_Memory; return }
			if property_fact.subject != assertion || property_fact.predicate != state.profile.terms.assertion_property do continue
			for target_index in 0..<store.fact_count(state.target) {
				target_id, target_fact, _, target_found := store.fact_at(state.target, target_index)
				if !target_found { state.error = .Out_Of_Memory; return }
				if target_fact.subject != assertion || (target_fact.predicate != state.profile.terms.target_individual && target_fact.predicate != state.profile.terms.target_value) do continue
				actual := store.id_for_fact(state.target, {subject = source_fact.object, predicate = property_fact.object, object = target_fact.object})
				if actual == store.INVALID_FACT_ID do continue
				if !add_violation(state, .Negative_Property_Assertion, []store.Fact_ID{type_fact_id, source_id, property_id, target_id, actual}) do return
			}
		}
	}
}

@(private) Max_Cardinality_Zero_State :: struct {
	base:                ^Check_State,
	max_cardinality_id:  store.Fact_ID,
	on_property_id:      store.Fact_ID,
	type_id:             store.Fact_ID,
}

@(private) max_cardinality_zero_sink :: proc(id: store.Fact_ID, _: store.Fact, _: store.Origin, user_data: rawptr) -> bool {
	state := cast(^Max_Cardinality_Zero_State)user_data
	return add_violation(state.base, .Max_Cardinality_Zero, []store.Fact_ID{state.max_cardinality_id, state.on_property_id, state.type_id, id})
}

// check_max_cardinality_zero implements W3C OWL 2 RL/RDF cls-maxc1. The
// conclusion is false, so it is representable without relaxing the strict RDF
// triple boundary used by the materializer.
@(private) check_max_cardinality_zero :: proc(state: ^Check_State, max_cardinality_id: store.Fact_ID, restriction: term.Term_ID) {
	for on_property_index in 0..<store.fact_count(state.target) {
		on_property_id, on_property_fact, _, on_property_found := store.fact_at(state.target, on_property_index)
		if !on_property_found { state.error = .Out_Of_Memory; return }
		if on_property_fact.subject != restriction || on_property_fact.predicate != state.profile.terms.on_property do continue
		for type_index in 0..<store.fact_count(state.target) {
			type_id, type_fact, _, type_found := store.fact_at(state.target, type_index)
			if !type_found { state.error = .Out_Of_Memory; return }
			if type_fact.predicate != state.profile.terms.rdf_type || type_fact.object != restriction do continue
			match_state := Max_Cardinality_Zero_State{
				base = state,
				max_cardinality_id = max_cardinality_id,
				on_property_id = on_property_id,
				type_id = type_id,
			}
			_ = store.match(state.target, {subject = type_fact.subject, predicate = on_property_fact.object}, max_cardinality_zero_sink, &match_state)
			if state.error != .None do return
		}
	}
}

// check_max_qualified_cardinality_zero implements cls-maxqc1 and cls-maxqc2.
// The former needs a representable type fact for the property object; the
// latter has owl:Thing as its class and therefore needs no object type fact.
@(private) check_max_qualified_cardinality_zero :: proc(state: ^Check_State, max_cardinality_id: store.Fact_ID, restriction: term.Term_ID) {
	for on_property_index in 0..<store.fact_count(state.target) {
		on_property_id, on_property_fact, _, on_property_found := store.fact_at(state.target, on_property_index)
		if !on_property_found { state.error = .Out_Of_Memory; return }
		if on_property_fact.subject != restriction || on_property_fact.predicate != state.profile.terms.on_property do continue
		for on_class_index in 0..<store.fact_count(state.target) {
			on_class_id, on_class_fact, _, on_class_found := store.fact_at(state.target, on_class_index)
			if !on_class_found { state.error = .Out_Of_Memory; return }
			if on_class_fact.subject != restriction || on_class_fact.predicate != state.profile.terms.on_class do continue
			for type_index in 0..<store.fact_count(state.target) {
				type_id, type_fact, _, type_found := store.fact_at(state.target, type_index)
				if !type_found { state.error = .Out_Of_Memory; return }
				if type_fact.predicate != state.profile.terms.rdf_type || type_fact.object != restriction do continue
				for property_index in 0..<store.fact_count(state.target) {
					property_id, property_fact, _, property_found := store.fact_at(state.target, property_index)
					if !property_found { state.error = .Out_Of_Memory; return }
					if property_fact.subject != type_fact.subject || property_fact.predicate != on_property_fact.object do continue
					if on_class_fact.object == state.profile.terms.owl_thing {
						if !add_violation(state, .Max_Qualified_Cardinality_Zero, []store.Fact_ID{max_cardinality_id, on_property_id, on_class_id, type_id, property_id}) do return
						continue
					}
					member_type := store.id_for_fact(state.target, {subject = property_fact.object, predicate = state.profile.terms.rdf_type, object = on_class_fact.object})
					if member_type != store.INVALID_FACT_ID && !add_violation(state, .Max_Qualified_Cardinality_Zero, []store.Fact_ID{max_cardinality_id, on_property_id, on_class_id, type_id, property_id, member_type}) do return
				}
				if state.error != .None do return
			}
		}
	}
}

// check_consistency scans an already materialized closure for the documented
// OWL 2 RL false rules. It does not mutate the store. On configured report
// limit or allocation failure, report is cleared and the error is explicit.
check_consistency :: proc(profile: ^Profile, target: ^store.Store, report: ^Report, options: Consistency_Options = {}) -> Consistency_Error_Code {
	if options.max_violations < 0 do return .Invalid_Option
	if !profile.initialized do return .Invalid_Profile
	clear_report(report)
	state := Check_State{profile = profile, target = target, report = report, options = options, seen = make(map[Violation_Key]bool)}
	defer delete(state.seen)
	for index in 0..<store.fact_count(target) {
		if state.error != .None do break
		id, fact, _, found := store.fact_at(target, index)
		if !found { state.error = .Out_Of_Memory; break }
		switch fact.predicate {
		case profile.terms.max_cardinality:
			if fact.object == profile.terms.zero_cardinality do check_max_cardinality_zero(&state, id, fact.subject)
		case profile.terms.max_qualified_cardinality:
			if fact.object == profile.terms.zero_cardinality do check_max_qualified_cardinality_zero(&state, id, fact.subject)
		case profile.terms.same_as:
			other := store.id_for_fact(target, {subject = fact.subject, predicate = profile.terms.different_from, object = fact.object})
			if other != store.INVALID_FACT_ID do _ = add_violation(&state, .Same_As_Different_From, []store.Fact_ID{id, other})
		case profile.terms.disjoint_with:
			class_state := Class_State{base = &state, rule_fact_id = id, other_class = fact.object, kind = .Disjoint_Classes}
			_ = store.match(target, {predicate = profile.terms.rdf_type, object = fact.subject}, class_sink, &class_state)
		case profile.terms.complement_of:
			class_state := Class_State{base = &state, rule_fact_id = id, other_class = fact.object, kind = .Complement_Classes}
			_ = store.match(target, {predicate = profile.terms.rdf_type, object = fact.subject}, class_sink, &class_state)
		case profile.terms.property_disjoint_with:
			property_state := Property_State{base = &state, rule_fact_id = id, other_predicate = fact.object}
			_ = store.match(target, {predicate = fact.subject}, property_sink, &property_state)
		case profile.terms.rdf_type:
			check_datatype_not_type(&state, id, fact)
			if state.error != .None do break
			if fact.object == profile.terms.owl_nothing {
				_ = add_violation(&state, .Nothing_Instance, []store.Fact_ID{id})
			} else if fact.object == profile.terms.irreflexive_property {
				irreflexive_state := Irreflexive_State{base = &state, type_fact_id = id}
				_ = store.match(target, {predicate = fact.subject}, irreflexive_sink, &irreflexive_state)
			} else if fact.object == profile.terms.asymmetric_property {
				asymmetric_state := Asymmetric_State{base = &state, type_fact_id = id}
				_ = store.match(target, {predicate = fact.subject}, asymmetric_sink, &asymmetric_state)
			} else if fact.object == profile.terms.all_disjoint_classes {
				members_state := All_Disjoint_Members_State{base = &state, group_type_fact_id = id}
				_ = store.match(target, {subject = fact.subject, predicate = profile.terms.members}, all_disjoint_members_sink, &members_state)
			} else if fact.object == profile.terms.all_disjoint_properties {
				members_state := All_Disjoint_Properties_Members_State{base = &state, group_type_fact_id = id}
				_ = store.match(target, {subject = fact.subject, predicate = profile.terms.members}, all_disjoint_properties_members_sink, &members_state)
			} else if fact.object == profile.terms.all_different {
				members_state := All_Different_Members_State{base = &state, group_type_fact_id = id}
				_ = store.match(target, {subject = fact.subject, predicate = profile.terms.members}, all_different_members_sink, &members_state)
				if state.error != .None do break
				_ = store.match(target, {subject = fact.subject, predicate = profile.terms.distinct_members}, all_different_members_sink, &members_state)
			} else if fact.object == profile.terms.negative_property_assertion {
				check_negative_property_assertion(&state, id, fact.subject)
			}
		}
	}
	if state.error != .None {
		clear_report(report)
		return state.error
	}
	return .None
}

// Materialize_Check_Result distinguishes rule-materialization failure from a
// completed closure that is inconsistent under the implemented OWL 2 RL rules.
Materialize_Check_Result :: struct {
	materialization: rule.Result,
	consistency:    Consistency_Error_Code,
	consistent:      bool,
}

materialize_checked :: proc(profile: ^Profile, target: ^store.Store, report: ^Report, materialization_options: rule.Options = {}, consistency_options: Consistency_Options = {}) -> Materialize_Check_Result {
	result := Materialize_Check_Result{materialization = materialize(profile, target, materialization_options)}
	if result.materialization.error != .None {
		clear_report(report)
		return result
	}
	result.consistency = check_consistency(profile, target, report, consistency_options)
	result.consistent = result.consistency == .None && violation_count(report) == 0
	return result
}

// Materialize_All_Check_Result distinguishes a complete supported closure that
// is inconsistent from a failed complete materialization. When materialization
// succeeds, inferred facts and closure provenance remain available even when
// consistent is false or the consistency scan itself reports an explicit error.
Materialize_All_Check_Result :: struct {
	materialization: Materialize_All_Result,
	consistency:    Consistency_Error_Code,
	consistent:      bool,
}

// materialize_all_checked first reaches the full supported static/list
// fixpoint, then scans that committed closure for implemented OWL false rules.
// A materialization error clears report and leaves the caller store and prior
// complete-closure provenance unchanged. A consistency error or nonempty report
// never retracts a successfully committed closure.
materialize_all_checked :: proc(profile: ^Profile, target: ^store.Store, report: ^Report, materialization_options: Materialize_All_Options = {}, consistency_options: Consistency_Options = {}) -> Materialize_All_Check_Result {
	result := Materialize_All_Check_Result{materialization = materialize_all(profile, target, materialization_options)}
	if result.materialization.error != .None {
		clear_report(report)
		return result
	}
	result.consistency = check_consistency(profile, target, report, consistency_options)
	result.consistent = result.consistency == .None && violation_count(report) == 0
	return result
}

// Generalized_Datatype_Check_Result pairs the generalized datatype closure
// with its false-rule report. As with the strict checked entry points, a
// nonempty report never retracts a successfully committed closure.
Generalized_Datatype_Check_Result :: struct {
	materialization: Generalized_Datatype_Result,
	consistency:    Consistency_Error_Code,
	consistent:      bool,
}

materialize_generalized_datatypes_checked :: proc(profile: ^Profile, target: ^store.Store, report: ^Report, materialization_options: Generalized_Datatype_Options = {}, consistency_options: Consistency_Options = {}) -> Generalized_Datatype_Check_Result {
	result := Generalized_Datatype_Check_Result{materialization = materialize_generalized_datatypes(profile, target, materialization_options)}
	if result.materialization.error != .None {
		clear_report(report)
		return result
	}
	result.consistency = check_consistency(profile, target, report, consistency_options)
	result.consistent = result.consistency == .None && violation_count(report) == 0
	return result
}
