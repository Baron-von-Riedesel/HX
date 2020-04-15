
        .386
if ?FLAT
        .MODEL FLAT, stdcall
else
        .MODEL SMALL, stdcall
endif
		option casemap:none
        option proc:private

        include winbase.inc
        include wingdi.inc
        include dgdi32.inc
        include macros.inc

        .CODE

SaveDC proc public hdc:DWORD

		invoke _GDImalloc2, sizeof DCOBJ
        .if (eax)
			@strace	<"SaveDC(): saved state=", eax>
        	pushad
            mov edi, eax
            mov esi, hdc
            mov ecx, sizeof DCOBJ
            rep movsb
            popad
            mov ecx, hdc
            mov [ecx].DCOBJ.pStack, eax
            xor eax, eax
            .while ([ecx].DCOBJ.pStack)
            	mov ecx, [ecx].DCOBJ.pStack
                inc eax
            .endw
        .endif
		@strace	<"SaveDC(", hdc, ")=", eax>
        ret
		align 4
        
SaveDC endp

;--- restore a previously saved DC state
;--- if nSavedDC is negative, restore the state from a relative position
;--- else restore from absolute position

RestoreDC proc public uses esi hdc:DWORD, nSavedDC:DWORD

		mov ecx, hdc
        mov edx, nSavedDC
		xor eax, eax
        .if (sdword ptr edx < 0)
        	.while (edx)
            	mov ecx, [ecx].DCOBJ.pStack
                jecxz exit
            	inc edx
            .endw
        .elseif (edx)
        	.while ([ecx].DCOBJ.pStack)		;go to end of queue and count
            	mov ecx, [ecx].DCOBJ.pStack	;the number of saved states in EAX
				inc eax
            .endw
            .if (eax < edx)					;exit if there are not enough
            	xor eax, eax				;saved states
                jmp exit
            .endif
            mov ecx, hdc
            sub eax, edx
        	.repeat
            	mov ecx, [ecx].DCOBJ.pStack
                dec eax
            .until (sdword ptr eax < 0)
        .endif
        mov eax, hdc
        mov edx, [eax].DCOBJ.pStack			;free all states which are 
        mov [eax].DCOBJ.pStack, ecx			;between hdc and ecx
        .while (edx && (edx != ecx))
        	push ecx
            push [edx].DCOBJ.pStack
            invoke _GDIfree, edx
            pop edx
            pop ecx
        .endw
        pushad
        mov esi, ecx
        mov edi, hdc
        mov ecx, sizeof DCOBJ
        rep movsb
        popad
        mov edx, hdc
        mov eax, [ecx].DCOBJ.pStack
        mov [edx].DCOBJ.pStack, eax
        @mov esi, 1					;return the number of saved states+1
        .while (eax)
            inc esi
            mov eax, [eax].DCOBJ.pStack
        .endw
        invoke _GDIfree, ecx
        mov eax, esi
exit:        
		@strace	<"RestoreDC(", hdc, ", ", nSavedDC, ")=", eax>
        ret
		align 4
        
RestoreDC endp

		end
