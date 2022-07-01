
;--- dummy InitApp to allow 16-bit C programs compiled with MS VC 1.52
;--- to run with DPMILD16.

	.286
	.model small
        
	.code

InitApp proc far pascal hInst:word
	mov  ax,1
	ret
InitApp endp

	end

