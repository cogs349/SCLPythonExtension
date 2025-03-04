include "python.grm"
include "ASNOne.Grm"
include "annot.ovr"

redefine program
    ...
    [repeat py_translation]
end redefine

redefine rule_definition
    ...
  | [repeat py_translation]
end redefine

define py_translation
     [callback_function]
   | [parse_function]
   | [free_function]
   | [type_tag_translation]
   | [type_translation]
   | [import_translation]
end define

define callback_function
    [statement_or_newline]
end define

define parse_function
    [statement_or_newline]
end define

define free_function
    [statement_or_newline]
end define

define type_tag_translation
    [statement_or_newline]
end define

define type_translation
    [type_decision_translation]
  | [type_rule_translation]
end define

define type_decision_translation
    % enum and union
    % now just union
    %[statement_or_newline]
    [statement_or_newline]
end define

define import_translation
    [import_statement]
end define

define type_rule_translation
    % struct
    [statement_or_newline]
end define

redefine member_declaration
    [statement_or_newline]
end redefine

function main
    replace [program]
	P [program]

    by
	P [processEachModule]
	  [assembleProgram]
end function

rule processEachModule
    replace $ [module_definition]
      ModName [id] 'DEFINITIONS ::= 'BEGIN
         Exports [opt export_block]
	 Imports [opt import_block]
	 Rules [repeat rule_definition]
      'END

    %construct Msg [stringlit]
	%_ [createModuleGlobalVars]

    construct TagTypeName [id]
    	ModName [+ '_TagType]

    % Copy of all the [type_decision_definition]s in the program
    construct TypeDecisions [repeat type_decision_definition]
	    _ [^ Rules]

    by
      ModName  'DEFINITIONS ::= 'BEGIN
         Exports
	 Imports
	 Rules
	     [translateTypeDecisions Exports TagTypeName]
	     [translateTypeStructs Exports]
	     [addModules Imports]
      'END
end rule

rule translateTypeDecisions Exports [opt export_block] TagTypeName [id]
    replace [repeat rule_definition]
	'[ UniqueName [id] '^ ShortName [id] '] Annot [annotation] '::= TypeDec [type_decision] SclAdd [opt scl_additions]
	Rest [repeat rule_definition]
 
    construct Types [repeat type_reference]
    	_ [^ TypeDec]

    %construct TagTypeName [id]
    	%UniqueName [+ '_TagType]

    %construct FirstUnder [number]
        %_ [index UniqueName '_]
    %construct ModName [id]
    	%UniqueName [: 1 FirstUnder]

    % one enum type for all tags
    %construct TagTypeName [id]
    	%ModName [+ '_TagType]

    construct body [repeat member_declaration]
	_ [addUnionElementForEachType each Types]

    construct CallbackFunction [repeat rule_definition]
        _ [addGeneralCallback UniqueName SclAdd]

    construct ParseFunction [repeat rule_definition]
        _ [addParseFunction UniqueName Exports]

    construct FreeFunction [repeat rule_definition]
        _ [addFreeFunction UniqueName Exports]

    construct TypeDecTrans [classdef]
        %'typedef 'enum '{ Enumerators'} TagTypeName ';
	'class TagTypeName':

    by
        TypeDecTrans
		body
	    [. CallbackFunction]
	    [. ParseFunction]
	    [. FreeFunction]
	    [. Rest]
end rule

define struct_container
    [repeat type_translation]
end define

function assembleProgram
    % input name is FILENAME_somephase.scl5
    % assume outputs are:
    %   FILENAME_Parser.c
    %   FILENAME_Definitions.h
    import TXLinput [stringlit]

    construct StemName [stringlit]
    	TXLinput
	    [trimToBase]
	    [removeAfterUnderscore]
    
    construct IncludeGuard [stringlit]
        _ [+ '"_"]
	  [+ StemName]
	  [toupper]
	  %[putp "Name stem is %"]
	  [+ '"DEFINITION_PY_"]
	  %[putp "Include Name is %"]

    replace [program]
	P [program]
    construct CallbackProtos [repeat callback_function]
    	_ [^ P]
    construct CallBackProtos2 [repeat py_translation]
    	_ [reparse CallbackProtos]
    construct ParseProtos [repeat parse_function]
    	_ [^ P]
    construct ParseProtos2 [repeat py_translation]
    	_ [reparse ParseProtos]
    construct FreeProtos [repeat free_function]
    	_ [^ P]
    construct FreeProtos2 [repeat py_translation]
    	_ [reparse FreeProtos]
    construct Structs [repeat type_translation]
    	_ [^ P]

    construct Includes [repeat import_translation]
    	_ [^ P]
    construct Includes2 [repeat py_translation]
    	_ [reparse Includes]
	  [putp "INcludes are %"]

    construct Preface [repeat py_translation]
	'import struct
	from packet 'import PDU
    by
        Preface
	[. Includes2]
        [. Structs]
	[. CallBackProtos2]
	[. ParseProtos2]
	[. FreeProtos2]
end function 
% reset per module global variables

function trimToBase
    replace [stringlit]
	FileName [stringlit]
    construct Slash [number]
    	_ [index FileName '/]
	  [+ 1]
    construct FileNameLength [number]
    	_ [# FileName]
    where
    	Slash [> 0]
	      [< FileNameLength]
    by
       FileName [: Slash FileNameLength]
end function

function removeAfterUnderscore
    replace [stringlit]
	FileName [stringlit]
    construct Under [number]
    	_ [index FileName '_]
    where
    	Under [> 0]
    by
       FileName [: 1 Under]
end function

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% generate fields of union type for type decision
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function addUnionElementForEachType aType [type_reference]
    replace [repeat member_declaration]
    	Elements [repeat member_declaration]
    by
    	Elements
	    [addUnionElementIfNoDot aType]
	    [addUnionElementIfDot aType]
end function

function addUnionElementIfNoDot aType [type_reference]
    deconstruct aType
    	Name [id] Annot [annotation]
    construct Member [member_declaration]
    	Name Name [tolower];
    replace [repeat member_declaration]
    	Elements [repeat member_declaration]
    by
    	Elements [. Member]
end function

function addUnionElementIfDot aType [type_reference]
    deconstruct aType
    	_ [id] . Name [id] Annot [annotation]
    construct Member [member_declaration]
    	Name Name [tolower];
    replace [repeat member_declaration]
    	Elements [repeat member_declaration]
    by
    	Elements [. Member]
end function

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%5
% Step 1 - Structure Type 
% Structure Type Decisions become c structures with one or more C fields for
% each element
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%5

rule translateTypeStructs Exports [opt export_block]
    replace [repeat rule_definition]
	'[ UniqueName [id] '^ ShortName [id] '] Annot [annotation] '::= 'SEQUENCE  SZ [opt size_constraint]  
		Elements [list struct_element] _[opt ',]
	SclAdd [opt scl_additions]
	Rest [repeat rule_definition]
 

    construct body [repeat member_declaration]
	_ [addMemberForEachElement SclAdd each Elements]

    construct CallbackFunction [repeat rule_definition]
        _ [addGeneralCallback UniqueName SclAdd]
	  [addSubmessageCallback UniqueName SclAdd]

    construct ParseFunction [repeat rule_definition]
        _ [addParseFunction UniqueName Exports]

    construct FreeFunction [repeat rule_definition]
        _ [addFreeFunction UniqueName Exports]
    
    construct PyClass [type_rule_translation]
	'class UniqueName '( 'PDU '):
	    body
	
    construct PyClass2 [repeat rule_definition]
    	PyClass
    by
    	PyClass2
	    [. CallbackFunction]
	    [. ParseFunction]
	    [. FreeFunction]
	    [. Rest]
end rule

function addMemberForEachElement SclAdd [opt scl_additions] anElement [struct_element]
    replace [repeat member_declaration]
        Elements [repeat member_declaration]
    by
    	Elements
	   [addSizeBasedType anElement]
	   [addExternalSizeBasedType anElement]
	   [addSizeBasedOptionalType anElement]
	   [addExternalSizeBasedOptionalType anElement]
	   [addSetOfType anElement]
	   [addExternalSetOfType anElement]
	   [addInteger anElement]
	   [addReal anElement]
	   [addDynamicOctetString anElement]
	   [addStaticOctetString anElement]
	   [addStaticOctetStringLarge anElement]
	   [addPositionField anElement]
	   [addSlackField anElement SclAdd]
	   [addSlackModField anElement SclAdd]
end function

% Function to generate the variable for a [size_based_type] definition;
% This is a variable with a user defined type
% must not be optional
function addSizeBasedType anElement [struct_element]
    deconstruct anElement
	'[ Unique [id] '^ ShortName [id] '] Annots [annotation] ElementType [id] '('SIZE 'DEFINED') TypeAttr [repeat type_attribute]

    deconstruct not * [optional] TypeAttr
    	'OPTIONAL

    construct Decl [member_declaration]
	ShortName [tolower]

    replace [repeat member_declaration]
	Members [repeat member_declaration]
    by
	Members [. Decl]	% Append variable to the body
end function

function addExternalSizeBasedType anElement [struct_element]
    deconstruct anElement
	'[ Unique [id] '^ ShortName [id] '] Annots [annotation] ModualName[id] . ExportedType [id] '('SIZE 'DEFINED') TypeAttr [repeat type_attribute]

    deconstruct not * [optional] TypeAttr
    	'OPTIONAL

    construct Decl [member_declaration]
	ShortName [tolower]

    replace [repeat member_declaration]
	Members [repeat member_declaration]
    by
	Members [. Decl]	% Append variable to the body
end function

% Function to generate the variable for a [size_based_type] definition; 
% This is a variable with a user defined type declared as a pointer
function addSizeBasedOptionalType anElement [struct_element]
    deconstruct anElement
	'[ Unique [id] '^ ShortName [id] '] Annots [annotation] ElementType [id] '('SIZE 'DEFINED') TypeAttr [repeat type_attribute]

    % must have optional
    deconstruct * [optional] TypeAttr
    	'OPTIONAL

    construct Decl [member_declaration]
	ShortName [tolower]	% Pointer variable
    replace [repeat member_declaration]
	MD [repeat member_declaration]
    by
	MD [. Decl]	% Append variable to the body
end function

% Function to generate the variable for a [size_based_type] definition; 
% This is a variable with a user defined type declared as a pointer
function addExternalSizeBasedOptionalType anElement [struct_element]
    deconstruct anElement
	'[ Unique [id] '^ ShortName [id] '] Annots [annotation] ModuleName [id] . ExternalType [id] '('SIZE 'DEFINED') TypeAttr [repeat type_attribute] 

    % must have optional
    deconstruct * [optional] TypeAttr
    	'OPTIONAL

    construct Decl [member_declaration]
	ShortName [tolower]	% Pointer variable
    replace [repeat member_declaration]
	MD [repeat member_declaration]
    by
	MD [. Decl]	% Append variable to the body
end function

function addSetOfType anElement [struct_element]
    deconstruct anElement
	'[ Unique [id] '^ ShortName [id] '] Annots [annotation] 'SET 'OF ElementType [id]  '('SIZE 'CONSTRAINED') TypeAttr [repeat type_attribute]

    construct Decl [repeat member_declaration]
	ShortName [+ "length"] [tolower]
	ShortName [+ "Count"] [tolower]
	ShortName[tolower]

    replace [repeat member_declaration]
	MD [repeat member_declaration]
    by
	MD [. Decl] % Append variables to the body
end function

function addExternalSetOfType anElement [struct_element]
    deconstruct anElement
	'[ Unique [id] '^ ShortName [id] '] Annots [annotation] 'SET 'OF ModuleName [id] . ExternalType [id]  '('SIZE 'CONSTRAINED') TypeAttr [repeat type_attribute]

    construct Decl [repeat member_declaration]
	ShortName [+ "length"] [tolower]
	ShortName [+ "Count"] [tolower]
	ShortName[tolower]

    replace [repeat member_declaration]
	MD [repeat member_declaration]
    by
	MD [. Decl] % Append variables to the body
end function



% Function to generate the variable for an [integer_type] definition;
% This is a variable with a specified number of bits required. It is
% stored as a uint# where the # is calculated from the [element_type]

define number_pair
    [number] [number]
end define

function addInteger anElement [struct_element]
	deconstruct anElement
	    '[ Unique [id] '^ ShortName [id] '] Annots [annotation] 'INTEGER '( 'SIZE Size [number] 'BYTES ') TypeAttr [repeat type_attribute]

	% current implmentation limited to 64 bit integers
	% Also have to round the number to the nearest integer size

	% TODO, TD 2021 should we have round everyitng to 32/64? Does it matter
	% for speed?


	% remove this message if we implement bigints in a separate rule in the future.
	construct Msg [number]
		Size [checkMaxNumberSize 'integer '8]

	where
		Size [<= 8]	% If the number of bytes is greater than 8 it
				% cannot be represented as a uint
	construct SizeTable [repeat number_pair]
	   1 8 2 16 3 32 4 32 5 64 6 64 7 64 8 64

	deconstruct * [number_pair] SizeTable
		Size NumBits [number]

	construct IntType [id]
	   _ [+ 'uint] [+ NumBits] [+ '_t]

	construct Decl [member_declaration]
		IntType ShortName [tolower]

	replace [repeat member_declaration]
	    MD [repeat member_declaration]
	by
	    MD [. Decl]	% Append variable to the body
end function


function checkMaxNumberSize Type [id] Max [number]
    match [number]
	N [number]
    where
    	N [> Max]
    construct Msg [stringlit]
    	_ [+ '"Error: Size "]
	  [+ N]
	  [+ '"is larger than the maximum implemented "]
	  [+ Type]
	  [+ '"size("]
	  [+ Max]
	  [+ '")"]
	  [print]
end function


function checkRealSizes ShortName [id]
   match [number]
   	N [number]
   where not 
   	N [= '4]
	  [= '8]
   construct Msg [stringlit]
   	_ [+ '"Size "]
	  [+ N]
	  [+ '" of REAL field "]
	  [+ ShortName]
	  [+ '" is not 4 or 8"]
	  [print]
end function

% Function to generate the variable for an [real_type] definition;
% This is a variable with a specified number of bits required in 
% floating point precision. only 4 -> float and 8 -> double is supported

function addReal anElement [struct_element]
    deconstruct anElement
	'[ Unique [id] '^ ShortName [id] '] Annots [annotation] 'REAL '( 'SIZE Size [number] 'BYTES ') TypeAttr [repeat type_attribute]

    construct Msg [number]
	Size [checkRealSizes ShortName]

    where
	Size [= 4]	% 4 bytes equates to float predefined size
	     [= 8]
    
    construct RealType [id]
    	_ [addIf 'float '4 Size]
	  [addIf 'double '8 Size]

    construct Decl [member_declaration]
	RealType ShortName [tolower]
	
    replace [repeat member_declaration]
	MD [repeat member_declaration]
    by
	MD [. Decl]	% Append variable to the body
end function

function addIf Type [id] TargetSize [number] FieldSize[number]
    where
    	TargetSize [= FieldSize]
    replace [id]
    	_ [id]
    by
    	Type
end function

% Function to generate the variable for a dynamic [octet_type] definition;
% This is a variable with a dynamic size, defined externally. It is represented
% as a character pointer which will be dynamically allocated during the parse.
% The length is stored in a variable for reference

function addDynamicOctetString anElement [struct_element]
    deconstruct anElement
	'[ Unique [id] '^ ShortName [id] '] Annots [annotation] 'OCTET 'STRING '( 'SIZE 'CONSTRAINED ') TypeAttr [repeat type_attribute]

    construct Decl [repeat member_declaration]
	ShortName [+ "_length" ][tolower]	% Size of the pointer array
	ShortName [tolower]		% Dyanmic pointer array

    replace [repeat member_declaration]
	MD [repeat member_declaration]
    by
	MD [. Decl]	% Append variable to the body
end function


% Function to generate the variable for an [octet_type] definition;
% This is represented as a uint with a static size to hold all the info
% which is determined from the [element_type] definition

function addStaticOctetString anElement [struct_element]
    deconstruct anElement
	'[ Unique [id] '^ ShortName [id] '] Annots [annotation] 'OCTET 'STRING '( 'SIZE Size [number] 'BYTES ') TypeAttr [repeat type_attribute]

    where
	Size [<= 8]	% If the number of bytes is greater than 8 it
			% cannot be represented as a uint

    construct SizeTable [repeat number_pair]
	1 8 2 16 3 32 4 32 5 64 6 64 7 64 8 64

    deconstruct * [number_pair] SizeTable
	Size NumBits [number]

    construct IntType [id]
       _ [+ 'uint] [+ NumBits] [+ '_t]

    construct Decl [member_declaration]
	ShortName[tolower]

    replace [repeat member_declaration]
	MD [repeat member_declaration]
    by
	MD [. Decl]	% Append variable to the body
end function


% Function to generate the variable for an [octet_type] definition;
% This is represented as a character array with a static size 
% that is determined from the [element_type] definition as the
% size is too large for a uint
function addStaticOctetStringLarge anElement [struct_element]
    deconstruct anElement
	'[ Unique [id] '^ ShortName [id] '] Annots [annotation] 'OCTET 'STRING '( 'SIZE Size [number] 'BYTES ') TypeAttr [repeat type_attribute]
    where
	Size [> 8]	% If the size is greater than 8 bytes it is too
					% large to store in a uint and must be stored in
					% an array
    construct Decl [member_declaration]
	ShortName[tolower] '[ Size ']

    replace [repeat member_declaration]
	MD [repeat member_declaration]
    by
	MD [. Decl]	% Append variable to the body
end function

% psotiion fields are added if there is either a SAVEPOS in the type or
% an @POS in the Annots
function addPositionField anElement [struct_element]
    deconstruct anElement
	'[ Unique [id] '^ ShortName [id] '] Annots [annotation] Type [type]

    construct IsThereAPos [number]
    	_ [OneIfSAVEPOSInType Type]
	  [OneIfPOSInAnnots Annots]

    where
    	IsThereAPos [= '1]

    construct Decl [member_declaration]
	ShortName[tolower] [+ '"_POS"]
    replace [repeat member_declaration]
	MD [repeat member_declaration]
    by
	MD [. Decl]	% Append variable to the body
end function

function OneIfPOSInAnnots Annots [annotation]
    deconstruct * [position_used] Annots
    	'@ 'POS
    replace [number]
    	_ [number]
    by
    	'1
end function

% If a field of a uswer defined type is the subject of a length constraint, it may not take
% up the length constraint. The remaining bytes of the length constraint are skipped as slack bytes
% to represent this in the data structure we have an integer field that holds how many bytes were skipped.
function addSlackField anElement [struct_element] SclAdd [opt scl_additions]
    deconstruct anElement
	'[ Unique [id] '^ ShortName [id] '] Annots [annotation] ElementType [id] '('SIZE 'DEFINED') TypeAttr [repeat type_attribute]


    deconstruct * [slack] TypeAttr
    	SLACK _ [opt MODNUM]


    deconstruct * [construction_parameter] SclAdd
    	LENGTH '( '[ Unique '^ ShortName '] ') '== _ [additive_expression] _ [opt size_unit]

    construct Decl [member_declaration]
	ShortName[tolower] [+ '"_SLACK"]
    replace [repeat member_declaration]
	MD [repeat member_declaration]
    by
	MD [. Decl]	% Append variable to the body
end function

function addSlackModField anElement [struct_element] SclAdd [opt scl_additions]
    deconstruct anElement
	'[ Unique [id] '^ ShortName [id] '] Annots [annotation] ElementType [id] '('SIZE 'DEFINED') TypeAttr [repeat type_attribute]


    deconstruct * [slack] TypeAttr
    	SLACK _ [MODNUM]

% not sure if we need the number in the field name, probably not
    construct Decl [member_declaration]
	ShortName[tolower] [+ '"_SLACKMOD"]
    replace [repeat member_declaration]
	MD [repeat member_declaration]
    by
	MD [. Decl]	% Append variable to the body
end function

function OneIfSAVEPOSInType Type [type]
    deconstruct * [save_position] Type
    	'SAVEPOS
    replace [number]
    	_ [number]
    by
    	'1
end function

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Add general callback function
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function addGeneralCallback UniqueName [id] SclAdd [opt scl_additions]
    % Only support unannotated Callback Statement fron user
    % not from annotation for submessage callback.
    %deconstruct  * [transfer_statement] SclAdd
    	%'Callback
    where
    	SclAdd [hasPlainCallback]
	       [hasSubmessageOptimizedCallback]

    replace [repeat rule_definition]
	_ [repeat rule_definition]

    construct FunctionName [id]
    	UniqueName [+ '_callback]

    construct CallBack [callback_function]
    	FunctionName '( UniqueName [tolower] , PDU ) ;
    	
    by
        CallBack
end function

function hasPlainCallback
    match * [transfer_statement] 
    	'Callback 
end function

function hasSubmessageOptimizedCallback
    match * [transfer_statement] 
    	'Callback @ _ [id] _ [id]
end function

% SORTING UTILITY

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Add Submessage Callback
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function addSubmessageCallback UniqueName [id] SclAdd [opt scl_additions]
    % Add submessage callback using Callback annotation from submessage markup
    deconstruct  * [transfer_statement] SclAdd
    	'Callback ParentUID [id] ParentField [id]
    replace [repeat rule_definition]
	_ [repeat rule_definition]

    construct FunctionName [id]
    	UniqueName [+ '_callback]

    construct CallBack [callback_function]
    	FunctionName '( ParentUID [tolower] , UniqueName [tolower] , PDU )
    	
    by
        CallBack
end function

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Add parse and free function
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function addParseFunction UniqueName [id] Exports [opt export_block]
    deconstruct * [id] Exports
        UniqueName
    replace [repeat rule_definition]
	_ [repeat rule_definition]

    construct FunctionName [id]
        _ [+ 'parse]
    	  [+ UniqueName]

    construct ParseFn [parse_function]
    	FunctionName '( UniqueName [tolower] , PDU, name, endianness )
    	
    by
        ParseFn
end function

function addFreeFunction UniqueName [id] Exports [opt export_block]
    deconstruct * [id] Exports
        UniqueName
    replace [repeat rule_definition]
	_ [repeat rule_definition]

    construct FunctionName [id]
        _ [+ 'free]
    	  [+ UniqueName]

    construct FreeFn [free_function]
    	FunctionName '( UniqueName [tolower] ) 
    	
    by
        FreeFn
end function

function addModules Imports [opt import_block]
    replace [repeat rule_definition]
	Rules [repeat rule_definition]

    deconstruct * [list import_list+] Imports
    	Import_List [list import_list+]

    construct Includes [repeat rule_definition]
    	_  [includeModDef Rules each Import_List]
    by
    	Rules [. Includes]
end function

function includeModDef Rules [repeat rule_definition] anImportList [import_list]
    replace [repeat rule_definition]
        Defs [repeat rule_definition]

    deconstruct anImportList
	_ [list decl] 'FROM ModName [id]

%TODO - need a deep deconstruct in to rules to verify that Module is used.

    construct IncludeString [stringlit]
    	_ [+ "import \""]
	  [+ ModName]
	  [+ '"_PDU\""]

    construct  IncludeLine [preprocessor_line]
        _ [parse IncludeString]
    construct ImportLine [import_translation]
    	IncludeLine

    construct RD [rule_definition]
    	ImportLine
    by
        Defs [. RD]
end function