// Package owlrl implements an intentionally small, documented OWL 2 RL rule
// cluster composed with the RDFS Core profile.
package owlrl

import rdf "odin-rdf:rdf"
import rdfs "../rdfs"
import rule "../rule"
import store "../store"
import term "../term"

OWL_RL_CAX_EQC1 :: rule.Rule_ID(101)
OWL_RL_CAX_EQC2 :: rule.Rule_ID(102)
OWL_RL_PRP_EQP1 :: rule.Rule_ID(103)
OWL_RL_PRP_EQP2 :: rule.Rule_ID(104)
OWL_RL_PRP_INV1 :: rule.Rule_ID(105)
OWL_RL_PRP_INV2 :: rule.Rule_ID(106)
OWL_RL_PRP_SYMP :: rule.Rule_ID(107)
OWL_RL_PRP_TRP  :: rule.Rule_ID(108)
OWL_RL_SCM_DOM1 :: rule.Rule_ID(109)
OWL_RL_SCM_DOM2 :: rule.Rule_ID(110)
OWL_RL_SCM_RNG1 :: rule.Rule_ID(111)
OWL_RL_SCM_RNG2 :: rule.Rule_ID(112)
OWL_RL_CLS_HV1  :: rule.Rule_ID(113)
OWL_RL_CLS_HV2  :: rule.Rule_ID(114)
OWL_RL_CLS_SVF1 :: rule.Rule_ID(115)
OWL_RL_CLS_SVF2 :: rule.Rule_ID(116)
OWL_RL_CLS_AVF  :: rule.Rule_ID(117)
OWL_RL_SCM_EQC1 :: rule.Rule_ID(118)
OWL_RL_SCM_EQC1_REVERSE :: rule.Rule_ID(119)
OWL_RL_SCM_EQC2 :: rule.Rule_ID(120)
OWL_RL_SCM_EQP1 :: rule.Rule_ID(121)
OWL_RL_SCM_EQP1_REVERSE :: rule.Rule_ID(122)
OWL_RL_SCM_EQP2 :: rule.Rule_ID(123)
OWL_RL_SCM_HV   :: rule.Rule_ID(124)
OWL_RL_SCM_SVF1 :: rule.Rule_ID(125)
OWL_RL_SCM_SVF2 :: rule.Rule_ID(126)
OWL_RL_SCM_AVF1 :: rule.Rule_ID(127)
OWL_RL_SCM_AVF2 :: rule.Rule_ID(128)
OWL_RL_EQ_REF_SUBJECT   :: rule.Rule_ID(129)
OWL_RL_EQ_REF_PREDICATE :: rule.Rule_ID(130)
OWL_RL_EQ_REF_OBJECT    :: rule.Rule_ID(131)
OWL_RL_EQ_SYM           :: rule.Rule_ID(132)
OWL_RL_EQ_TRANS         :: rule.Rule_ID(133)
OWL_RL_EQ_REP_SUBJECT   :: rule.Rule_ID(134)
OWL_RL_EQ_REP_PREDICATE :: rule.Rule_ID(135)
OWL_RL_EQ_REP_OBJECT    :: rule.Rule_ID(136)
OWL_RL_PRP_FP            :: rule.Rule_ID(137)
OWL_RL_PRP_IFP           :: rule.Rule_ID(138)
OWL_RL_CLS_HAS_SELF1     :: rule.Rule_ID(139)
OWL_RL_CLS_HAS_SELF2     :: rule.Rule_ID(140)
OWL_RL_SCM_CLS_SUBCLASS  :: rule.Rule_ID(141)
OWL_RL_SCM_CLS_EQUIVALENT :: rule.Rule_ID(142)
OWL_RL_SCM_CLS_THING     :: rule.Rule_ID(143)
OWL_RL_SCM_CLS_NOTHING   :: rule.Rule_ID(144)
OWL_RL_SCM_OP_SUBPROPERTY :: rule.Rule_ID(145)
OWL_RL_SCM_OP_EQUIVALENT :: rule.Rule_ID(146)
OWL_RL_SCM_DP_SUBPROPERTY :: rule.Rule_ID(147)
OWL_RL_SCM_DP_EQUIVALENT :: rule.Rule_ID(148)
OWL_RL_CLS_OO            :: rule.Rule_ID(149)
OWL_RL_CLS_INT1          :: rule.Rule_ID(150)
OWL_RL_CLS_INT2          :: rule.Rule_ID(151)
OWL_RL_CLS_UNI           :: rule.Rule_ID(152)
OWL_RL_PRP_SPO2          :: rule.Rule_ID(153)
OWL_RL_CLS_MAXC2         :: rule.Rule_ID(154)
OWL_RL_CLS_MAXQC3        :: rule.Rule_ID(155)
OWL_RL_CLS_MAXQC4        :: rule.Rule_ID(156)
OWL_RL_PRP_KEY           :: rule.Rule_ID(157)
OWL_RL_PRP_AP            :: rule.Rule_ID(158)
OWL_RL_DT_TYPE1          :: rule.Rule_ID(159)
OWL_RL_DT_TYPE2          :: rule.Rule_ID(160)
OWL_RL_DT_EQ             :: rule.Rule_ID(161)
OWL_RL_DT_DIFF           :: rule.Rule_ID(162)

OWL_EQUIVALENT_CLASS    :: "http://www.w3.org/2002/07/owl#equivalentClass"
OWL_EQUIVALENT_PROPERTY :: "http://www.w3.org/2002/07/owl#equivalentProperty"
OWL_INVERSE_OF           :: "http://www.w3.org/2002/07/owl#inverseOf"
OWL_SYMMETRIC_PROPERTY   :: "http://www.w3.org/2002/07/owl#SymmetricProperty"
OWL_TRANSITIVE_PROPERTY  :: "http://www.w3.org/2002/07/owl#TransitiveProperty"
OWL_HAS_VALUE            :: "http://www.w3.org/2002/07/owl#hasValue"
OWL_ON_PROPERTY          :: "http://www.w3.org/2002/07/owl#onProperty"
OWL_SOME_VALUES_FROM     :: "http://www.w3.org/2002/07/owl#someValuesFrom"
OWL_ALL_VALUES_FROM      :: "http://www.w3.org/2002/07/owl#allValuesFrom"
OWL_THING                :: "http://www.w3.org/2002/07/owl#Thing"
OWL_SAME_AS              :: "http://www.w3.org/2002/07/owl#sameAs"
OWL_FUNCTIONAL_PROPERTY  :: "http://www.w3.org/2002/07/owl#FunctionalProperty"
OWL_INVERSE_FUNCTIONAL_PROPERTY :: "http://www.w3.org/2002/07/owl#InverseFunctionalProperty"
OWL_DIFFERENT_FROM       :: "http://www.w3.org/2002/07/owl#differentFrom"
OWL_DISJOINT_WITH         :: "http://www.w3.org/2002/07/owl#disjointWith"
OWL_PROPERTY_DISJOINT_WITH :: "http://www.w3.org/2002/07/owl#propertyDisjointWith"
OWL_IRREFLEXIVE_PROPERTY  :: "http://www.w3.org/2002/07/owl#IrreflexiveProperty"
OWL_ASYMMETRIC_PROPERTY   :: "http://www.w3.org/2002/07/owl#AsymmetricProperty"
OWL_ONE_OF                :: "http://www.w3.org/2002/07/owl#oneOf"
OWL_INTERSECTION_OF       :: "http://www.w3.org/2002/07/owl#intersectionOf"
OWL_UNION_OF              :: "http://www.w3.org/2002/07/owl#unionOf"
OWL_COMPLEMENT_OF         :: "http://www.w3.org/2002/07/owl#complementOf"
OWL_ALL_DISJOINT_CLASSES  :: "http://www.w3.org/2002/07/owl#AllDisjointClasses"
OWL_ALL_DISJOINT_PROPERTIES :: "http://www.w3.org/2002/07/owl#AllDisjointProperties"
OWL_ALL_DIFFERENT         :: "http://www.w3.org/2002/07/owl#AllDifferent"
OWL_MEMBERS               :: "http://www.w3.org/2002/07/owl#members"
OWL_DISTINCT_MEMBERS      :: "http://www.w3.org/2002/07/owl#distinctMembers"
OWL_NEGATIVE_PROPERTY_ASSERTION :: "http://www.w3.org/2002/07/owl#NegativePropertyAssertion"
OWL_SOURCE_INDIVIDUAL     :: "http://www.w3.org/2002/07/owl#sourceIndividual"
OWL_ASSERTION_PROPERTY    :: "http://www.w3.org/2002/07/owl#assertionProperty"
OWL_TARGET_INDIVIDUAL     :: "http://www.w3.org/2002/07/owl#targetIndividual"
OWL_TARGET_VALUE          :: "http://www.w3.org/2002/07/owl#targetValue"
OWL_PROPERTY_CHAIN_AXIOM  :: "http://www.w3.org/2002/07/owl#propertyChainAxiom"
OWL_HAS_SELF              :: "http://www.w3.org/2002/07/owl#hasSelf"
OWL_CLASS                 :: "http://www.w3.org/2002/07/owl#Class"
OWL_NOTHING               :: "http://www.w3.org/2002/07/owl#Nothing"
OWL_OBJECT_PROPERTY       :: "http://www.w3.org/2002/07/owl#ObjectProperty"
OWL_DATATYPE_PROPERTY     :: "http://www.w3.org/2002/07/owl#DatatypeProperty"
OWL_HAS_KEY               :: "http://www.w3.org/2002/07/owl#hasKey"
OWL_MAX_CARDINALITY       :: "http://www.w3.org/2002/07/owl#maxCardinality"
OWL_MAX_QUALIFIED_CARDINALITY :: "http://www.w3.org/2002/07/owl#maxQualifiedCardinality"
OWL_ON_CLASS              :: "http://www.w3.org/2002/07/owl#onClass"
OWL_ANNOTATION_PROPERTY   :: "http://www.w3.org/2002/07/owl#AnnotationProperty"
OWL_DEPRECATED            :: "http://www.w3.org/2002/07/owl#deprecated"
OWL_VERSION_INFO          :: "http://www.w3.org/2002/07/owl#versionInfo"
OWL_PRIOR_VERSION         :: "http://www.w3.org/2002/07/owl#priorVersion"
OWL_BACKWARD_COMPATIBLE_WITH :: "http://www.w3.org/2002/07/owl#backwardCompatibleWith"
OWL_INCOMPATIBLE_WITH     :: "http://www.w3.org/2002/07/owl#incompatibleWith"
XSD_BOOLEAN               :: "http://www.w3.org/2001/XMLSchema#boolean"
XSD_NON_NEGATIVE_INTEGER  :: "http://www.w3.org/2001/XMLSchema#nonNegativeInteger"
RDF_FIRST                 :: "http://www.w3.org/1999/02/22-rdf-syntax-ns#first"
RDF_REST                  :: "http://www.w3.org/1999/02/22-rdf-syntax-ns#rest"
RDF_NIL                   :: "http://www.w3.org/1999/02/22-rdf-syntax-ns#nil"
RDFS_LABEL                :: "http://www.w3.org/2000/01/rdf-schema#label"
RDFS_COMMENT              :: "http://www.w3.org/2000/01/rdf-schema#comment"
RDFS_SEE_ALSO             :: "http://www.w3.org/2000/01/rdf-schema#seeAlso"
RDFS_IS_DEFINED_BY        :: "http://www.w3.org/2000/01/rdf-schema#isDefinedBy"
RDFS_DATATYPE             :: "http://www.w3.org/2000/01/rdf-schema#Datatype"

Terms :: struct {
	rdf_type:            term.Term_ID,
	subclass_of:          term.Term_ID,
	subproperty_of:       term.Term_ID,
	domain:               term.Term_ID,
	range:                term.Term_ID,
	equivalent_class:    term.Term_ID,
	equivalent_property: term.Term_ID,
	inverse_of:           term.Term_ID,
	symmetric_property:   term.Term_ID,
	transitive_property:  term.Term_ID,
	has_value:            term.Term_ID,
	on_property:          term.Term_ID,
	some_values_from:     term.Term_ID,
	all_values_from:      term.Term_ID,
	owl_thing:            term.Term_ID,
	same_as:              term.Term_ID,
	functional_property:  term.Term_ID,
	inverse_functional_property: term.Term_ID,
	different_from:       term.Term_ID,
	disjoint_with:        term.Term_ID,
	property_disjoint_with: term.Term_ID,
	irreflexive_property: term.Term_ID,
	asymmetric_property:  term.Term_ID,
	rdf_first:            term.Term_ID,
	rdf_rest:             term.Term_ID,
	rdf_nil:              term.Term_ID,
	one_of:               term.Term_ID,
	intersection_of:      term.Term_ID,
	union_of:             term.Term_ID,
	complement_of:        term.Term_ID,
	all_disjoint_classes: term.Term_ID,
	all_disjoint_properties: term.Term_ID,
	all_different:         term.Term_ID,
	members:              term.Term_ID,
	distinct_members:     term.Term_ID,
	negative_property_assertion: term.Term_ID,
	source_individual:    term.Term_ID,
	assertion_property:   term.Term_ID,
	target_individual:    term.Term_ID,
	target_value:         term.Term_ID,
	property_chain_axiom: term.Term_ID,
	has_self:             term.Term_ID,
	true_value:           term.Term_ID,
	owl_class:            term.Term_ID,
	owl_nothing:          term.Term_ID,
	object_property:      term.Term_ID,
	datatype_property:    term.Term_ID,
	has_key:              term.Term_ID,
	max_cardinality:      term.Term_ID,
	zero_cardinality:     term.Term_ID,
	one_cardinality:      term.Term_ID,
	max_qualified_cardinality: term.Term_ID,
	on_class:             term.Term_ID,
	annotation_property:  term.Term_ID,
	annotation_properties: [9]term.Term_ID,
	rdfs_datatype:        term.Term_ID,
	owl_rl_datatypes:     [32]term.Term_ID,
}

Error_Code :: enum { None, Store_Error, RDFS_Error }

error_message :: proc(code: Error_Code) -> string {
	switch code {
	case .None:       return "no error"
	case .Store_Error: return "store rejected OWL RL vocabulary constants"
	case .RDFS_Error:  return "could not initialize composed RDFS Core profile"
	}
	return "unknown OWL RL profile error"
}

@(private) Definition :: struct {
	body: [8]rule.Triple_Template,
	head: [1]rule.Triple_Template,
}

// Profile owns a combined ninety-eight-rule table: RDFS Core plus ninety-two
// static instances of fifty-three documented OWL 2 RL directions. prp-ap has
// nine zero-body instances and dt-type1 has thirty-two, one per W3C resource.
// Do not copy it after init because Rule slices borrow embedded definitions.
Profile :: struct {
	rdfs:         rdfs.Profile,
	terms:        Terms,
	definitions:  [92]Definition,
	rules:        [98]rule.Rule,
	materializer: rule.Materializer,
	closure_provenance: Closure_Provenance,
	initialized:  bool,
}

@(private) set_one_rule :: proc(profile: ^Profile, index: int, id: rule.Rule_ID, body: rule.Triple_Template, head: rule.Triple_Template) {
	definition_index := index - 6
	profile.definitions[definition_index].body[0] = body
	profile.definitions[definition_index].head = {head}
	profile.rules[index] = {
		id = id,
		body = profile.definitions[definition_index].body[:1],
		head = profile.definitions[definition_index].head[:],
	}
}

@(private) set_zero_rule :: proc(profile: ^Profile, index: int, id: rule.Rule_ID, head: rule.Triple_Template) {
	definition_index := index - 6
	profile.definitions[definition_index].head = {head}
	profile.rules[index] = {
		id = id,
		body = profile.definitions[definition_index].body[:0],
		head = profile.definitions[definition_index].head[:],
	}
}

@(private) set_two_rule :: proc(profile: ^Profile, index: int, id: rule.Rule_ID, body: [2]rule.Triple_Template, head: rule.Triple_Template) {
	definition_index := index - 6
	profile.definitions[definition_index].body[0] = body[0]
	profile.definitions[definition_index].body[1] = body[1]
	profile.definitions[definition_index].head = {head}
	profile.rules[index] = {
		id = id,
		body = profile.definitions[definition_index].body[:2],
		head = profile.definitions[definition_index].head[:],
	}
}

@(private) set_three_rule :: proc(profile: ^Profile, index: int, id: rule.Rule_ID, body: [3]rule.Triple_Template, head: rule.Triple_Template) {
	definition_index := index - 6
	profile.definitions[definition_index].body[0] = body[0]
	profile.definitions[definition_index].body[1] = body[1]
	profile.definitions[definition_index].body[2] = body[2]
	profile.definitions[definition_index].head = {head}
	profile.rules[index] = {
		id = id,
		body = profile.definitions[definition_index].body[:3],
		head = profile.definitions[definition_index].head[:],
	}
}

@(private) set_four_rule :: proc(profile: ^Profile, index: int, id: rule.Rule_ID, body: [4]rule.Triple_Template, head: rule.Triple_Template) {
	definition_index := index - 6
	profile.definitions[definition_index].body[0] = body[0]
	profile.definitions[definition_index].body[1] = body[1]
	profile.definitions[definition_index].body[2] = body[2]
	profile.definitions[definition_index].body[3] = body[3]
	profile.definitions[definition_index].head = {head}
	profile.rules[index] = {
		id = id,
		body = profile.definitions[definition_index].body[:4],
		head = profile.definitions[definition_index].head[:],
	}
}

@(private) set_five_rule :: proc(profile: ^Profile, index: int, id: rule.Rule_ID, body: [5]rule.Triple_Template, head: rule.Triple_Template) {
	definition_index := index - 6
	profile.definitions[definition_index].body[0] = body[0]
	profile.definitions[definition_index].body[1] = body[1]
	profile.definitions[definition_index].body[2] = body[2]
	profile.definitions[definition_index].body[3] = body[3]
	profile.definitions[definition_index].body[4] = body[4]
	profile.definitions[definition_index].head = {head}
	profile.rules[index] = {
		id = id,
		body = profile.definitions[definition_index].body[:5],
		head = profile.definitions[definition_index].head[:],
	}
}

@(private) set_six_rule :: proc(profile: ^Profile, index: int, id: rule.Rule_ID, body: [6]rule.Triple_Template, head: rule.Triple_Template) {
	definition_index := index - 6
	for body_index in 0..<6 do profile.definitions[definition_index].body[body_index] = body[body_index]
	profile.definitions[definition_index].head = {head}
	profile.rules[index] = {
		id = id,
		body = profile.definitions[definition_index].body[:6],
		head = profile.definitions[definition_index].head[:],
	}
}

@(private) set_eight_rule :: proc(profile: ^Profile, index: int, id: rule.Rule_ID, body: [8]rule.Triple_Template, head: rule.Triple_Template) {
	definition_index := index - 6
	profile.definitions[definition_index].body = body
	profile.definitions[definition_index].head = {head}
	profile.rules[index] = {
		id = id,
		body = profile.definitions[definition_index].body[:],
		head = profile.definitions[definition_index].head[:],
	}
}

// init atomically reserves both the RDFS and this profile's vocabulary before
// initializing the composed RDFS profile. This prevents a term-limit error
// from leaving a partially admitted OWL RL vocabulary batch.
init :: proc(profile: ^Profile, target: ^store.Store) -> (Error_Code, store.Error_Code) {
	base_values := [63]rdf.Term{
		rdf.iri(rdfs.RDF_TYPE), rdf.iri(rdfs.RDFS_SUBCLASS), rdf.iri(rdfs.RDFS_SUBPROPERTY),
		rdf.iri(rdfs.RDFS_DOMAIN_IRI), rdf.iri(rdfs.RDFS_RANGE_IRI),
		rdf.iri(OWL_EQUIVALENT_CLASS), rdf.iri(OWL_EQUIVALENT_PROPERTY), rdf.iri(OWL_INVERSE_OF),
		rdf.iri(OWL_SYMMETRIC_PROPERTY), rdf.iri(OWL_TRANSITIVE_PROPERTY),
		rdf.iri(OWL_HAS_VALUE), rdf.iri(OWL_ON_PROPERTY), rdf.iri(OWL_SOME_VALUES_FROM),
		rdf.iri(OWL_ALL_VALUES_FROM), rdf.iri(OWL_THING),
		rdf.iri(OWL_SAME_AS),
		rdf.iri(OWL_FUNCTIONAL_PROPERTY), rdf.iri(OWL_INVERSE_FUNCTIONAL_PROPERTY),
		rdf.iri(OWL_DIFFERENT_FROM), rdf.iri(OWL_DISJOINT_WITH), rdf.iri(OWL_PROPERTY_DISJOINT_WITH),
		rdf.iri(OWL_IRREFLEXIVE_PROPERTY), rdf.iri(OWL_ASYMMETRIC_PROPERTY),
		rdf.iri(RDF_FIRST), rdf.iri(RDF_REST), rdf.iri(RDF_NIL),
		rdf.iri(OWL_ONE_OF),
		rdf.iri(OWL_INTERSECTION_OF),
		rdf.iri(OWL_UNION_OF),
		rdf.iri(OWL_COMPLEMENT_OF),
		rdf.iri(OWL_ALL_DISJOINT_CLASSES), rdf.iri(OWL_ALL_DISJOINT_PROPERTIES), rdf.iri(OWL_ALL_DIFFERENT), rdf.iri(OWL_MEMBERS),
		rdf.iri(OWL_NEGATIVE_PROPERTY_ASSERTION), rdf.iri(OWL_SOURCE_INDIVIDUAL), rdf.iri(OWL_ASSERTION_PROPERTY),
		rdf.iri(OWL_TARGET_INDIVIDUAL), rdf.iri(OWL_TARGET_VALUE),
		rdf.iri(OWL_PROPERTY_CHAIN_AXIOM),
		rdf.iri(OWL_HAS_SELF), rdf.typed_literal("true", XSD_BOOLEAN),
		rdf.iri(OWL_CLASS), rdf.iri(OWL_NOTHING),
		rdf.iri(OWL_OBJECT_PROPERTY),
		rdf.iri(OWL_DATATYPE_PROPERTY),
		rdf.iri(OWL_HAS_KEY),
		rdf.iri(OWL_DISTINCT_MEMBERS),
		rdf.iri(OWL_MAX_CARDINALITY), rdf.typed_literal("0", XSD_NON_NEGATIVE_INTEGER), rdf.typed_literal("1", XSD_NON_NEGATIVE_INTEGER),
		rdf.iri(OWL_MAX_QUALIFIED_CARDINALITY), rdf.iri(OWL_ON_CLASS),
		rdf.iri(OWL_ANNOTATION_PROPERTY),
		rdf.iri(RDFS_LABEL), rdf.iri(RDFS_COMMENT), rdf.iri(RDFS_SEE_ALSO), rdf.iri(RDFS_IS_DEFINED_BY),
		rdf.iri(OWL_DEPRECATED), rdf.iri(OWL_VERSION_INFO), rdf.iri(OWL_PRIOR_VERSION), rdf.iri(OWL_BACKWARD_COMPATIBLE_WITH), rdf.iri(OWL_INCOMPATIBLE_WITH),
	}
	values: [96]rdf.Term
	for value, value_index in base_values do values[value_index] = value
	values[63] = rdf.iri(RDFS_DATATYPE)
	for datatype_iri, datatype_index in rdf.OWL_RL_DATATYPE_IRIS do values[64 + datatype_index] = rdf.iri(datatype_iri)
	ids: [96]term.Term_ID
	if store_error := store.intern_terms(target, values[:], ids[:]); store_error != .None do return .Store_Error, store_error
	rdfs_error, nested_store_error := rdfs.init(&profile.rdfs, target)
	if rdfs_error != .None do return .RDFS_Error, nested_store_error
	profile.terms = {
		rdf_type = ids[0],
		subclass_of = ids[1],
		subproperty_of = ids[2],
		domain = ids[3],
		range = ids[4],
		equivalent_class = ids[5],
		equivalent_property = ids[6],
		inverse_of = ids[7],
		symmetric_property = ids[8],
		transitive_property = ids[9],
		has_value = ids[10],
		on_property = ids[11],
		some_values_from = ids[12],
		all_values_from = ids[13],
		owl_thing = ids[14],
		same_as = ids[15],
		functional_property = ids[16],
		inverse_functional_property = ids[17],
		different_from = ids[18],
		disjoint_with = ids[19],
		property_disjoint_with = ids[20],
		irreflexive_property = ids[21],
		asymmetric_property = ids[22],
		rdf_first = ids[23],
		rdf_rest = ids[24],
		rdf_nil = ids[25],
		one_of = ids[26],
		intersection_of = ids[27],
		union_of = ids[28],
		complement_of = ids[29],
		all_disjoint_classes = ids[30],
		all_disjoint_properties = ids[31],
		all_different = ids[32],
		members = ids[33],
		negative_property_assertion = ids[34],
		source_individual = ids[35],
		assertion_property = ids[36],
		target_individual = ids[37],
		target_value = ids[38],
		property_chain_axiom = ids[39],
		has_self = ids[40],
		true_value = ids[41],
		owl_class = ids[42],
		owl_nothing = ids[43],
		object_property = ids[44],
		datatype_property = ids[45],
		has_key = ids[46],
		distinct_members = ids[47],
		max_cardinality = ids[48],
		zero_cardinality = ids[49],
		one_cardinality = ids[50],
		max_qualified_cardinality = ids[51],
		on_class = ids[52],
		annotation_property = ids[53],
		annotation_properties = {ids[54], ids[55], ids[56], ids[57], ids[58], ids[59], ids[60], ids[61], ids[62]},
		rdfs_datatype = ids[63],
	}
	for datatype_index in 0..<len(profile.terms.owl_rl_datatypes) do profile.terms.owl_rl_datatypes[datatype_index] = ids[64 + datatype_index]
	base_rules := rdfs.rule_set(&profile.rdfs)
	for index in 0..<len(base_rules) do profile.rules[index] = base_rules[index]
	c1, c2, x, p1, p2, y :=
		rule.Variable_ID(1), rule.Variable_ID(2), rule.Variable_ID(3),
		rule.Variable_ID(4), rule.Variable_ID(5), rule.Variable_ID(6)
	set_two_rule(profile, 6, OWL_RL_CAX_EQC1,
		{{rule.variable(c1), rule.constant(profile.terms.equivalent_class), rule.variable(c2)}, {rule.variable(x), rule.constant(profile.terms.rdf_type), rule.variable(c1)}},
		{rule.variable(x), rule.constant(profile.terms.rdf_type), rule.variable(c2)})
	set_two_rule(profile, 7, OWL_RL_CAX_EQC2,
		{{rule.variable(c1), rule.constant(profile.terms.equivalent_class), rule.variable(c2)}, {rule.variable(x), rule.constant(profile.terms.rdf_type), rule.variable(c2)}},
		{rule.variable(x), rule.constant(profile.terms.rdf_type), rule.variable(c1)})
	set_two_rule(profile, 8, OWL_RL_PRP_EQP1,
		{{rule.variable(p1), rule.constant(profile.terms.equivalent_property), rule.variable(p2)}, {rule.variable(x), rule.variable(p1), rule.variable(y)}},
		{rule.variable(x), rule.variable(p2), rule.variable(y)})
	set_two_rule(profile, 9, OWL_RL_PRP_EQP2,
		{{rule.variable(p1), rule.constant(profile.terms.equivalent_property), rule.variable(p2)}, {rule.variable(x), rule.variable(p2), rule.variable(y)}},
		{rule.variable(x), rule.variable(p1), rule.variable(y)})
	set_two_rule(profile, 10, OWL_RL_PRP_INV1,
		{{rule.variable(p1), rule.constant(profile.terms.inverse_of), rule.variable(p2)}, {rule.variable(x), rule.variable(p1), rule.variable(y)}},
		{rule.variable(y), rule.variable(p2), rule.variable(x)})
	set_two_rule(profile, 11, OWL_RL_PRP_INV2,
		{{rule.variable(p1), rule.constant(profile.terms.inverse_of), rule.variable(p2)}, {rule.variable(x), rule.variable(p2), rule.variable(y)}},
		{rule.variable(y), rule.variable(p1), rule.variable(x)})
	set_two_rule(profile, 12, OWL_RL_PRP_SYMP,
		{{rule.variable(p1), rule.constant(profile.terms.rdf_type), rule.constant(profile.terms.symmetric_property)}, {rule.variable(x), rule.variable(p1), rule.variable(y)}},
		{rule.variable(y), rule.variable(p1), rule.variable(x)})
	set_three_rule(profile, 13, OWL_RL_PRP_TRP,
		{{rule.variable(p1), rule.constant(profile.terms.rdf_type), rule.constant(profile.terms.transitive_property)}, {rule.variable(x), rule.variable(p1), rule.variable(y)}, {rule.variable(y), rule.variable(p1), rule.variable(c1)}},
		{rule.variable(x), rule.variable(p1), rule.variable(c1)})
	set_two_rule(profile, 14, OWL_RL_SCM_DOM1,
		{{rule.variable(p1), rule.constant(profile.terms.domain), rule.variable(c1)}, {rule.variable(c1), rule.constant(profile.terms.subclass_of), rule.variable(c2)}},
		{rule.variable(p1), rule.constant(profile.terms.domain), rule.variable(c2)})
	set_two_rule(profile, 15, OWL_RL_SCM_DOM2,
		{{rule.variable(p2), rule.constant(profile.terms.domain), rule.variable(c1)}, {rule.variable(p1), rule.constant(profile.terms.subproperty_of), rule.variable(p2)}},
		{rule.variable(p1), rule.constant(profile.terms.domain), rule.variable(c1)})
	set_two_rule(profile, 16, OWL_RL_SCM_RNG1,
		{{rule.variable(p1), rule.constant(profile.terms.range), rule.variable(c1)}, {rule.variable(c1), rule.constant(profile.terms.subclass_of), rule.variable(c2)}},
		{rule.variable(p1), rule.constant(profile.terms.range), rule.variable(c2)})
	set_two_rule(profile, 17, OWL_RL_SCM_RNG2,
		{{rule.variable(p2), rule.constant(profile.terms.range), rule.variable(c1)}, {rule.variable(p1), rule.constant(profile.terms.subproperty_of), rule.variable(p2)}},
		{rule.variable(p1), rule.constant(profile.terms.range), rule.variable(c1)})
	set_three_rule(profile, 18, OWL_RL_CLS_HV1,
		{{rule.variable(c1), rule.constant(profile.terms.has_value), rule.variable(y)}, {rule.variable(c1), rule.constant(profile.terms.on_property), rule.variable(p1)}, {rule.variable(x), rule.constant(profile.terms.rdf_type), rule.variable(c1)}},
		{rule.variable(x), rule.variable(p1), rule.variable(y)})
	set_three_rule(profile, 19, OWL_RL_CLS_HV2,
		{{rule.variable(c1), rule.constant(profile.terms.has_value), rule.variable(y)}, {rule.variable(c1), rule.constant(profile.terms.on_property), rule.variable(p1)}, {rule.variable(x), rule.variable(p1), rule.variable(y)}},
		{rule.variable(x), rule.constant(profile.terms.rdf_type), rule.variable(c1)})
	set_four_rule(profile, 20, OWL_RL_CLS_SVF1,
		{{rule.variable(c1), rule.constant(profile.terms.some_values_from), rule.variable(c2)}, {rule.variable(c1), rule.constant(profile.terms.on_property), rule.variable(p1)}, {rule.variable(x), rule.variable(p1), rule.variable(y)}, {rule.variable(y), rule.constant(profile.terms.rdf_type), rule.variable(c2)}},
		{rule.variable(x), rule.constant(profile.terms.rdf_type), rule.variable(c1)})
	set_three_rule(profile, 21, OWL_RL_CLS_SVF2,
		{{rule.variable(c1), rule.constant(profile.terms.some_values_from), rule.constant(profile.terms.owl_thing)}, {rule.variable(c1), rule.constant(profile.terms.on_property), rule.variable(p1)}, {rule.variable(x), rule.variable(p1), rule.variable(y)}},
		{rule.variable(x), rule.constant(profile.terms.rdf_type), rule.variable(c1)})
	set_four_rule(profile, 22, OWL_RL_CLS_AVF,
		{{rule.variable(c1), rule.constant(profile.terms.all_values_from), rule.variable(c2)}, {rule.variable(c1), rule.constant(profile.terms.on_property), rule.variable(p1)}, {rule.variable(x), rule.constant(profile.terms.rdf_type), rule.variable(c1)}, {rule.variable(x), rule.variable(p1), rule.variable(y)}},
		{rule.variable(y), rule.constant(profile.terms.rdf_type), rule.variable(c2)})
	set_one_rule(profile, 23, OWL_RL_SCM_EQC1,
		{rule.variable(c1), rule.constant(profile.terms.equivalent_class), rule.variable(c2)},
		{rule.variable(c1), rule.constant(profile.terms.subclass_of), rule.variable(c2)})
	set_one_rule(profile, 24, OWL_RL_SCM_EQC1_REVERSE,
		{rule.variable(c1), rule.constant(profile.terms.equivalent_class), rule.variable(c2)},
		{rule.variable(c2), rule.constant(profile.terms.subclass_of), rule.variable(c1)})
	set_two_rule(profile, 25, OWL_RL_SCM_EQC2,
		{{rule.variable(c1), rule.constant(profile.terms.subclass_of), rule.variable(c2)}, {rule.variable(c2), rule.constant(profile.terms.subclass_of), rule.variable(c1)}},
		{rule.variable(c1), rule.constant(profile.terms.equivalent_class), rule.variable(c2)})
	set_one_rule(profile, 26, OWL_RL_SCM_EQP1,
		{rule.variable(p1), rule.constant(profile.terms.equivalent_property), rule.variable(p2)},
		{rule.variable(p1), rule.constant(profile.terms.subproperty_of), rule.variable(p2)})
	set_one_rule(profile, 27, OWL_RL_SCM_EQP1_REVERSE,
		{rule.variable(p1), rule.constant(profile.terms.equivalent_property), rule.variable(p2)},
		{rule.variable(p2), rule.constant(profile.terms.subproperty_of), rule.variable(p1)})
	set_two_rule(profile, 28, OWL_RL_SCM_EQP2,
		{{rule.variable(p1), rule.constant(profile.terms.subproperty_of), rule.variable(p2)}, {rule.variable(p2), rule.constant(profile.terms.subproperty_of), rule.variable(p1)}},
		{rule.variable(p1), rule.constant(profile.terms.equivalent_property), rule.variable(p2)})
	set_five_rule(profile, 29, OWL_RL_SCM_HV,
		{{rule.variable(c1), rule.constant(profile.terms.has_value), rule.variable(y)}, {rule.variable(c1), rule.constant(profile.terms.on_property), rule.variable(p1)}, {rule.variable(c2), rule.constant(profile.terms.has_value), rule.variable(y)}, {rule.variable(c2), rule.constant(profile.terms.on_property), rule.variable(p2)}, {rule.variable(p1), rule.constant(profile.terms.subproperty_of), rule.variable(p2)}},
		{rule.variable(c1), rule.constant(profile.terms.subclass_of), rule.variable(c2)})
	set_five_rule(profile, 30, OWL_RL_SCM_SVF1,
		{{rule.variable(c1), rule.constant(profile.terms.some_values_from), rule.variable(x)}, {rule.variable(c1), rule.constant(profile.terms.on_property), rule.variable(p1)}, {rule.variable(c2), rule.constant(profile.terms.some_values_from), rule.variable(y)}, {rule.variable(c2), rule.constant(profile.terms.on_property), rule.variable(p1)}, {rule.variable(x), rule.constant(profile.terms.subclass_of), rule.variable(y)}},
		{rule.variable(c1), rule.constant(profile.terms.subclass_of), rule.variable(c2)})
	set_five_rule(profile, 31, OWL_RL_SCM_SVF2,
		{{rule.variable(c1), rule.constant(profile.terms.some_values_from), rule.variable(x)}, {rule.variable(c1), rule.constant(profile.terms.on_property), rule.variable(p1)}, {rule.variable(c2), rule.constant(profile.terms.some_values_from), rule.variable(x)}, {rule.variable(c2), rule.constant(profile.terms.on_property), rule.variable(p2)}, {rule.variable(p1), rule.constant(profile.terms.subproperty_of), rule.variable(p2)}},
		{rule.variable(c1), rule.constant(profile.terms.subclass_of), rule.variable(c2)})
	set_five_rule(profile, 32, OWL_RL_SCM_AVF1,
		{{rule.variable(c1), rule.constant(profile.terms.all_values_from), rule.variable(x)}, {rule.variable(c1), rule.constant(profile.terms.on_property), rule.variable(p1)}, {rule.variable(c2), rule.constant(profile.terms.all_values_from), rule.variable(y)}, {rule.variable(c2), rule.constant(profile.terms.on_property), rule.variable(p1)}, {rule.variable(x), rule.constant(profile.terms.subclass_of), rule.variable(y)}},
		{rule.variable(c1), rule.constant(profile.terms.subclass_of), rule.variable(c2)})
	set_five_rule(profile, 33, OWL_RL_SCM_AVF2,
		{{rule.variable(c1), rule.constant(profile.terms.all_values_from), rule.variable(x)}, {rule.variable(c1), rule.constant(profile.terms.on_property), rule.variable(p1)}, {rule.variable(c2), rule.constant(profile.terms.all_values_from), rule.variable(x)}, {rule.variable(c2), rule.constant(profile.terms.on_property), rule.variable(p2)}, {rule.variable(p1), rule.constant(profile.terms.subproperty_of), rule.variable(p2)}},
		{rule.variable(c2), rule.constant(profile.terms.subclass_of), rule.variable(c1)})
	set_one_rule(profile, 34, OWL_RL_EQ_REF_SUBJECT,
		{rule.variable(x), rule.variable(p1), rule.variable(y)},
		{rule.variable(x), rule.constant(profile.terms.same_as), rule.variable(x)})
	set_one_rule(profile, 35, OWL_RL_EQ_REF_PREDICATE,
		{rule.variable(x), rule.variable(p1), rule.variable(y)},
		{rule.variable(p1), rule.constant(profile.terms.same_as), rule.variable(p1)})
	set_one_rule(profile, 36, OWL_RL_EQ_REF_OBJECT,
		{rule.variable(x), rule.variable(p1), rule.variable(y)},
		{rule.variable(y), rule.constant(profile.terms.same_as), rule.variable(y)})
	set_one_rule(profile, 37, OWL_RL_EQ_SYM,
		{rule.variable(x), rule.constant(profile.terms.same_as), rule.variable(y)},
		{rule.variable(y), rule.constant(profile.terms.same_as), rule.variable(x)})
	set_two_rule(profile, 38, OWL_RL_EQ_TRANS,
		{{rule.variable(x), rule.constant(profile.terms.same_as), rule.variable(y)}, {rule.variable(y), rule.constant(profile.terms.same_as), rule.variable(c1)}},
		{rule.variable(x), rule.constant(profile.terms.same_as), rule.variable(c1)})
	set_two_rule(profile, 39, OWL_RL_EQ_REP_SUBJECT,
		{{rule.variable(x), rule.constant(profile.terms.same_as), rule.variable(c1)}, {rule.variable(x), rule.variable(p1), rule.variable(y)}},
		{rule.variable(c1), rule.variable(p1), rule.variable(y)})
	set_two_rule(profile, 40, OWL_RL_EQ_REP_PREDICATE,
		{{rule.variable(p1), rule.constant(profile.terms.same_as), rule.variable(p2)}, {rule.variable(x), rule.variable(p1), rule.variable(y)}},
		{rule.variable(x), rule.variable(p2), rule.variable(y)})
	set_two_rule(profile, 41, OWL_RL_EQ_REP_OBJECT,
		{{rule.variable(y), rule.constant(profile.terms.same_as), rule.variable(c1)}, {rule.variable(x), rule.variable(p1), rule.variable(y)}},
		{rule.variable(x), rule.variable(p1), rule.variable(c1)})
	set_three_rule(profile, 42, OWL_RL_PRP_FP,
		{{rule.variable(p1), rule.constant(profile.terms.rdf_type), rule.constant(profile.terms.functional_property)}, {rule.variable(x), rule.variable(p1), rule.variable(y)}, {rule.variable(x), rule.variable(p1), rule.variable(c1)}},
		{rule.variable(y), rule.constant(profile.terms.same_as), rule.variable(c1)})
	set_three_rule(profile, 43, OWL_RL_PRP_IFP,
		{{rule.variable(p1), rule.constant(profile.terms.rdf_type), rule.constant(profile.terms.inverse_functional_property)}, {rule.variable(x), rule.variable(p1), rule.variable(y)}, {rule.variable(c1), rule.variable(p1), rule.variable(y)}},
		{rule.variable(x), rule.constant(profile.terms.same_as), rule.variable(c1)})
	set_three_rule(profile, 44, OWL_RL_CLS_HAS_SELF1,
		{{rule.variable(c1), rule.constant(profile.terms.has_self), rule.constant(profile.terms.true_value)}, {rule.variable(c1), rule.constant(profile.terms.on_property), rule.variable(p1)}, {rule.variable(x), rule.constant(profile.terms.rdf_type), rule.variable(c1)}},
		{rule.variable(x), rule.variable(p1), rule.variable(x)})
	set_three_rule(profile, 45, OWL_RL_CLS_HAS_SELF2,
		{{rule.variable(c1), rule.constant(profile.terms.has_self), rule.constant(profile.terms.true_value)}, {rule.variable(c1), rule.constant(profile.terms.on_property), rule.variable(p1)}, {rule.variable(x), rule.variable(p1), rule.variable(x)}},
		{rule.variable(x), rule.constant(profile.terms.rdf_type), rule.variable(c1)})
	set_one_rule(profile, 46, OWL_RL_SCM_CLS_SUBCLASS,
		{rule.variable(c1), rule.constant(profile.terms.rdf_type), rule.constant(profile.terms.owl_class)},
		{rule.variable(c1), rule.constant(profile.terms.subclass_of), rule.variable(c1)})
	set_one_rule(profile, 47, OWL_RL_SCM_CLS_EQUIVALENT,
		{rule.variable(c1), rule.constant(profile.terms.rdf_type), rule.constant(profile.terms.owl_class)},
		{rule.variable(c1), rule.constant(profile.terms.equivalent_class), rule.variable(c1)})
	set_one_rule(profile, 48, OWL_RL_SCM_CLS_THING,
		{rule.variable(c1), rule.constant(profile.terms.rdf_type), rule.constant(profile.terms.owl_class)},
		{rule.variable(c1), rule.constant(profile.terms.subclass_of), rule.constant(profile.terms.owl_thing)})
	set_one_rule(profile, 49, OWL_RL_SCM_CLS_NOTHING,
		{rule.variable(c1), rule.constant(profile.terms.rdf_type), rule.constant(profile.terms.owl_class)},
		{rule.constant(profile.terms.owl_nothing), rule.constant(profile.terms.subclass_of), rule.variable(c1)})
	set_one_rule(profile, 50, OWL_RL_SCM_OP_SUBPROPERTY,
		{rule.variable(p1), rule.constant(profile.terms.rdf_type), rule.constant(profile.terms.object_property)},
		{rule.variable(p1), rule.constant(profile.terms.subproperty_of), rule.variable(p1)})
	set_one_rule(profile, 51, OWL_RL_SCM_OP_EQUIVALENT,
		{rule.variable(p1), rule.constant(profile.terms.rdf_type), rule.constant(profile.terms.object_property)},
		{rule.variable(p1), rule.constant(profile.terms.equivalent_property), rule.variable(p1)})
	set_one_rule(profile, 52, OWL_RL_SCM_DP_SUBPROPERTY,
		{rule.variable(p1), rule.constant(profile.terms.rdf_type), rule.constant(profile.terms.datatype_property)},
		{rule.variable(p1), rule.constant(profile.terms.subproperty_of), rule.variable(p1)})
	set_one_rule(profile, 53, OWL_RL_SCM_DP_EQUIVALENT,
		{rule.variable(p1), rule.constant(profile.terms.rdf_type), rule.constant(profile.terms.datatype_property)},
		{rule.variable(p1), rule.constant(profile.terms.equivalent_property), rule.variable(p1)})
	set_five_rule(profile, 54, OWL_RL_CLS_MAXC2,
		{{rule.variable(c1), rule.constant(profile.terms.max_cardinality), rule.constant(profile.terms.one_cardinality)}, {rule.variable(c1), rule.constant(profile.terms.on_property), rule.variable(p1)}, {rule.variable(x), rule.constant(profile.terms.rdf_type), rule.variable(c1)}, {rule.variable(x), rule.variable(p1), rule.variable(y)}, {rule.variable(x), rule.variable(p1), rule.variable(c2)}},
		{rule.variable(y), rule.constant(profile.terms.same_as), rule.variable(c2)})
	set_eight_rule(profile, 55, OWL_RL_CLS_MAXQC3,
		{{rule.variable(c1), rule.constant(profile.terms.max_qualified_cardinality), rule.constant(profile.terms.one_cardinality)}, {rule.variable(c1), rule.constant(profile.terms.on_property), rule.variable(p1)}, {rule.variable(c1), rule.constant(profile.terms.on_class), rule.variable(c2)}, {rule.variable(x), rule.constant(profile.terms.rdf_type), rule.variable(c1)}, {rule.variable(x), rule.variable(p1), rule.variable(y)}, {rule.variable(y), rule.constant(profile.terms.rdf_type), rule.variable(c2)}, {rule.variable(x), rule.variable(p1), rule.variable(p2)}, {rule.variable(p2), rule.constant(profile.terms.rdf_type), rule.variable(c2)}},
		{rule.variable(y), rule.constant(profile.terms.same_as), rule.variable(p2)})
	set_six_rule(profile, 56, OWL_RL_CLS_MAXQC4,
		{{rule.variable(c1), rule.constant(profile.terms.max_qualified_cardinality), rule.constant(profile.terms.one_cardinality)}, {rule.variable(c1), rule.constant(profile.terms.on_property), rule.variable(p1)}, {rule.variable(c1), rule.constant(profile.terms.on_class), rule.constant(profile.terms.owl_thing)}, {rule.variable(x), rule.constant(profile.terms.rdf_type), rule.variable(c1)}, {rule.variable(x), rule.variable(p1), rule.variable(y)}, {rule.variable(x), rule.variable(p1), rule.variable(p2)}},
		{rule.variable(y), rule.constant(profile.terms.same_as), rule.variable(p2)})
	for annotation_property, annotation_index in profile.terms.annotation_properties {
		set_zero_rule(profile, 57 + annotation_index, OWL_RL_PRP_AP,
			{rule.constant(annotation_property), rule.constant(profile.terms.rdf_type), rule.constant(profile.terms.annotation_property)})
	}
	for datatype, datatype_index in profile.terms.owl_rl_datatypes {
		set_zero_rule(profile, 66 + datatype_index, OWL_RL_DT_TYPE1,
			{rule.constant(datatype), rule.constant(profile.terms.rdf_type), rule.constant(profile.terms.rdfs_datatype)})
	}
	rule.init(&profile.materializer)
	init_closure_provenance(&profile.closure_provenance)
	profile.initialized = true
	return .None, .None
}

destroy :: proc(profile: ^Profile) {
	destroy_closure_provenance(&profile.closure_provenance)
	if profile.initialized do rule.destroy(&profile.materializer)
	rdfs.destroy(&profile.rdfs)
	profile^ = {}
}

// materialize reaches one joint fixpoint across RDFS Core and this OWL 2 RL
// cluster. No partial closure is committed when a configured rule limit fails.
materialize :: proc(profile: ^Profile, target: ^store.Store, options: rule.Options = {}) -> rule.Result {
	if !profile.initialized do return rule.Result{error = .Invalid_Rule}
	return rule.materialize(&profile.materializer, target, profile.rules[:], options)
}

// materialize_generalized reaches the static RDFS/OWL closure while retaining
// generalized RDF heads required by the W3C OWL 2 RL rule table. In particular,
// a literal may occur in inferred subject position. Asserted input remains
// strict RDF because store.insert_triple continues to validate RDF 1.1 terms.
// Use materialize_all for the current strict-RDF complete dynamic closure.
materialize_generalized :: proc(profile: ^Profile, target: ^store.Store, options: rule.Options = {}) -> rule.Result {
	if !profile.initialized do return rule.Result{error = .Invalid_Rule}
	generalized_options := options
	generalized_options.generalized_heads = true
	return rule.materialize(&profile.materializer, target, profile.rules[:], generalized_options)
}
