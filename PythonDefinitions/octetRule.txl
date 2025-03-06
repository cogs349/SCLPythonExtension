include "ASNOne.Grm"
include "python.grm"
include "annot.ovr"

redefine program
    [struct_element]
    | [repeat statement_or_newline]
end redefine

rule main
    replace [program]
        structElement [struct_element]
    construct Result [repeat statement_or_newline]
        _
    by
        Result [addMemberForEachElement structElement]
end rule

function addMemberForEachElement anElement [struct_element]
    replace [repeat statement_or_newline]
        Elements [repeat statement_or_newline]
    by
    	Elements
	   %[addSizeBasedType anElement]
	   %[addExternalSizeBasedType anElement]
	   %[addSizeBasedOptionalType anElement]
	   %[addExternalSizeBasedOptionalType anElement]
	   %[addSetOfType anElement]
	   %[addExternalSetOfType anElement]
	   %[addInteger anElement]
	   %[addReal anElement]
	   %[addDynamicOctetString anElement]
	   %[addStaticOctetString anElement]
	   [addStaticOctetStringLarge anElement]
	   %[addPositionField anElement]
	   %[addSlackField anElement SclAdd]
	   %[addSlackModField anElement SclAdd]
end function

% Function to generate the variable for an [octet_type] definition;
% This is represented as a uint with a static size to hold all the info
% which is determined from the [element_type] definition

define number_pair
    [number][number]
end define

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

    construct readFunction [id]
       _ [+ 'get_] [+ NumBits] [+ '_bits]

    construct NewLine [newline]
        _ [unquote ''\n']

    construct Decl [repeat statement_or_newline]
	self.ShortName[tolower] = self.readFunction() NewLine

    replace [repeat statement_or_newline]
	MD [repeat statement_or_newline]
    by
	MD [. Decl]	% Append variable to the body
end function

function addDynamicOctetString anElement [struct_element]
    deconstruct anElement
	'[ Unique [id] '^ ShortName [id] '] Annots [annotation] 'OCTET 'STRING '( 'SIZE 'CONSTRAINED ') TypeAttr [repeat type_attribute]

	construct NewLine [newline]
        _ [unquote ''\n']

    construct Decl [repeat statement_or_newline]
	ShortName [+ "_length"] = '['] NewLine

    replace [repeat statement_or_newline]
	MD [repeat statement_or_newline]
    by
	MD [. Decl]	% Append variable to the body
end function

% all ints in python are of variable size, which means
% even the larger Octet strings
function addStaticOctetStringLarge anElement [struct_element]
    deconstruct anElement
	'[ Unique [id] '^ ShortName [id] '] Annots [annotation] 'OCTET 'STRING '( 'SIZE Size [number] 'BYTES ') TypeAttr [repeat type_attribute]
    where
	Size [> 8]	% If the size is greater than 8 bytes it is too
					% large to store in a uint and must be stored in
					% an array

	construct NewLine [newline]
        _ [unquote ''\n']

    construct Decl [statement_or_newline]
	ShortName_octet_string = bytearray() NewLine

    replace [repeat statement_or_newline]
	MD [repeat statement_or_newline]
    by
	MD [. Decl]	% Append variable to the body
end function