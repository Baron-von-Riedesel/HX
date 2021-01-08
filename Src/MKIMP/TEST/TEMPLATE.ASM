
;--- MASM template source to define an import
;--- to be assembled without errors, it needs 2 external definitions:
;--- ml.exe -c -coff -D?IMP=<name> -Fo <name> template.asm
;--- usually this is not done manually but by running mkimp.

	.386
;    option casemap:none

@defimp macro name_
externdef name_:near
public __imp_&name_
__imp_&name_ dd name_
	endm

_DATA segment dword FLAT public 'DATA'

	@defimp %?IMP

_DATA ends

	end
