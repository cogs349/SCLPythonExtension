

functions are different in TXL than traditional languages.
in python and C, we are used to seeing functions called and
referenced with variables in them, returning a result.

in TXL, functions take a parse tree as input, and produce a replacement
parse tree. Variables in TXL are parse trees. there are no integers, floats etc...





the standard psuedocode for a function is as follows:

function functionName parameters [parameterType]

import, export, deconstruct or construct blocks go here

replace

    a pattern

by 

    a new pattern [applyExtraRules]

end function



"variables" in TXL transformations are initialized as follows:

function createVariable

replace [aTree]

    tree [aTree] %where tree becomes the variable that holds a parse tree of type aTree

by

    tree [transformation]

end function










Here is an example of a deconstruct and a construct


function addSizeBasedType anElement [struct_element]
    deconstruct anElement
    
	'[ Unique [id] '^ ShortName [id] '] Annots [annotation] ElementType [id] '('SIZE 'DEFINED') TypeAttr [repeat type_attribute]

    deconstruct not * [optional] TypeAttr
    	'OPTIONAL

    construct Decl [member_declaration]
	ElementType ShortName [tolower] ';

    replace [repeat member_declaration]
	Members [repeat member_declaration]
    by
	Members [. Decl]	% Append variable to the body
end function


functions can be search (*) functions, one pass ($) functions or recursive functions

if the contents of a replacement are a part of the KEYS section in any of the grammars, it
needs a single quote in front of it eg. 'int