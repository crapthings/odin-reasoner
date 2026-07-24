// Package rdfs implements the deliberately small RDFS Core materializer.
package rdfs

import rdf "odin-rdf:rdf"
import rule "../rule"
import store "../store"
import term "../term"

RDFS_SC       :: rule.Rule_ID(1)
RDFS_SC_TRANS :: rule.Rule_ID(2)
RDFS_SP       :: rule.Rule_ID(3)
RDFS_SP_TRANS :: rule.Rule_ID(4)
RDFS_DOMAIN   :: rule.Rule_ID(5)
RDFS_RANGE    :: rule.Rule_ID(6)

RDF_TYPE       :: "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
RDFS_SUBCLASS  :: "http://www.w3.org/2000/01/rdf-schema#subClassOf"
RDFS_SUBPROPERTY :: "http://www.w3.org/2000/01/rdf-schema#subPropertyOf"
RDFS_DOMAIN_IRI :: "http://www.w3.org/2000/01/rdf-schema#domain"
RDFS_RANGE_IRI  :: "http://www.w3.org/2000/01/rdf-schema#range"

Terms :: struct {
	rdf_type:        term.Term_ID,
	subclass_of:     term.Term_ID,
	subproperty_of:  term.Term_ID,
	domain:          term.Term_ID,
	range:           term.Term_ID,
}

Error_Code :: enum { None, Store_Error }

error_message :: proc(code: Error_Code) -> string {
	switch code {
	case .None:        return "no error"
	case .Store_Error: return "store rejected RDFS vocabulary constants"
	}
	return "unknown error"
}

@(private) Definition :: struct {
	body: [2]rule.Triple_Template,
	head: [1]rule.Triple_Template,
}

// Profile owns rule definitions and the provenance materializer. Do not copy a
// Profile after init because its Rule slices borrow its embedded definitions.
Profile :: struct {
	terms:       Terms,
	definitions: [6]Definition,
	rules:       [6]rule.Rule,
	materializer: rule.Materializer,
	initialized: bool,
}

@(private) set_rule :: proc(profile: ^Profile, index: int, id: rule.Rule_ID, body: [2]rule.Triple_Template, head: rule.Triple_Template) {
	profile.definitions[index].body = body
	profile.definitions[index].head = {head}
	profile.rules[index] = {id = id, body = profile.definitions[index].body[:], head = profile.definitions[index].head[:]}
}

// init admits the five RDFS Core vocabulary constants and creates only the six
// rules documented in profile.md. Term-limit failures are atomic for the batch.
init :: proc(profile: ^Profile, target: ^store.Store) -> (Error_Code, store.Error_Code) {
	values := [5]rdf.Term{
		rdf.iri(RDF_TYPE), rdf.iri(RDFS_SUBCLASS), rdf.iri(RDFS_SUBPROPERTY),
		rdf.iri(RDFS_DOMAIN_IRI), rdf.iri(RDFS_RANGE_IRI),
	}
	ids: [5]term.Term_ID
	if store_error := store.intern_terms(target, values[:], ids[:]); store_error != .None do return .Store_Error, store_error
	profile.terms = Terms{rdf_type = ids[0], subclass_of = ids[1], subproperty_of = ids[2], domain = ids[3], range = ids[4]}
	x, y, z, s, p, o, c, c1, c2, c3, p1, p2, p3 :=
		rule.Variable_ID(1), rule.Variable_ID(2), rule.Variable_ID(3), rule.Variable_ID(4),
		rule.Variable_ID(5), rule.Variable_ID(6), rule.Variable_ID(7), rule.Variable_ID(8),
		rule.Variable_ID(9), rule.Variable_ID(10), rule.Variable_ID(11), rule.Variable_ID(12), rule.Variable_ID(13)

	set_rule(profile, 0, RDFS_SC,
		{{rule.variable(c1), rule.constant(profile.terms.subclass_of), rule.variable(c2)}, {rule.variable(x), rule.constant(profile.terms.rdf_type), rule.variable(c1)}},
		{rule.variable(x), rule.constant(profile.terms.rdf_type), rule.variable(c2)})
	set_rule(profile, 1, RDFS_SC_TRANS,
		{{rule.variable(c1), rule.constant(profile.terms.subclass_of), rule.variable(c2)}, {rule.variable(c2), rule.constant(profile.terms.subclass_of), rule.variable(c3)}},
		{rule.variable(c1), rule.constant(profile.terms.subclass_of), rule.variable(c3)})
	set_rule(profile, 2, RDFS_SP,
		{{rule.variable(p1), rule.constant(profile.terms.subproperty_of), rule.variable(p2)}, {rule.variable(s), rule.variable(p1), rule.variable(o)}},
		{rule.variable(s), rule.variable(p2), rule.variable(o)})
	set_rule(profile, 3, RDFS_SP_TRANS,
		{{rule.variable(p1), rule.constant(profile.terms.subproperty_of), rule.variable(p2)}, {rule.variable(p2), rule.constant(profile.terms.subproperty_of), rule.variable(p3)}},
		{rule.variable(p1), rule.constant(profile.terms.subproperty_of), rule.variable(p3)})
	set_rule(profile, 4, RDFS_DOMAIN,
		{{rule.variable(p), rule.constant(profile.terms.domain), rule.variable(c)}, {rule.variable(s), rule.variable(p), rule.variable(o)}},
		{rule.variable(s), rule.constant(profile.terms.rdf_type), rule.variable(c)})
	set_rule(profile, 5, RDFS_RANGE,
		{{rule.variable(p), rule.constant(profile.terms.range), rule.variable(c)}, {rule.variable(s), rule.variable(p), rule.variable(o)}},
		{rule.variable(o), rule.constant(profile.terms.rdf_type), rule.variable(c)})
	rule.init(&profile.materializer)
	profile.initialized = true
	return .None, .None
}

destroy :: proc(profile: ^Profile) {
	if profile.initialized do rule.destroy(&profile.materializer)
	profile^ = {}
}

// materialize applies exactly the six RDFS Core rules. The returned rule.Result
// contains bounded fixpoint status and provenance remains in profile.materializer.
materialize :: proc(profile: ^Profile, target: ^store.Store, options: rule.Options = {}) -> rule.Result {
	if !profile.initialized do return rule.Result{error = .Invalid_Rule}
	return rule.materialize(&profile.materializer, target, profile.rules[:], options)
}

// rule_set borrows the six initialized RDFS Core rules. It is for a profile
// that deliberately composes this finite rule table into one materialization;
// the returned slice must not outlive profile or be mutated by the caller.
rule_set :: proc(profile: ^Profile) -> []rule.Rule {
	if !profile.initialized do return nil
	return profile.rules[:]
}
