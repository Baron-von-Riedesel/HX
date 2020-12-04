
;--- SafeArray implementation - currently dummy

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	include winbase.inc
	include macros.inc

	.CODE

;--- vt: VARIANT type
;--- cDims: number of dimensions
;--- pArray: array of bounds (1 for each dimension)

SafeArrayCreate proc public vt:DWORD, cDims:DWORD, pArray:ptr DWORD

	xor eax, eax
	@strace <"SafeArrayCreate(", vt, ", ", cDims, ", ", pArray, ")=", eax, " *** unsupp ***">
	ret
	align 4

SafeArrayCreate endp

SafeArrayDestroy proc public psa:ptr

	mov eax,E_INVALIDARG
	@strace <"SafeArrayDestroy(", psa, ")=", eax, " *** unsupp ***">
	ret
	align 4

SafeArrayDestroy endp

SafeArrayGetDim proc public psa:ptr

	mov eax,E_INVALIDARG
	@strace <"SafeArrayGetDim(", psa, ")=", eax, " *** unsupp ***">
	ret
	align 4

SafeArrayGetDim endp

SafeArrayGetElemsize proc public psa:ptr

	mov eax,E_INVALIDARG
	@strace <"SafeArrayGetElemsize(", psa, ")=", eax, " *** unsupp ***">
	ret
	align 4

SafeArrayGetElemsize endp

SafeArrayGetUBound proc public psa:ptr, nDim:DWORD, plUBound:ptr DWORD

	mov eax,E_INVALIDARG
	@strace <"SafeArrayGetUBound(", psa, ", ", nDim, ", ", plUBound, ")=", eax, " *** unsupp ***">
	ret
	align 4
        
SafeArrayGetUBound endp

SafeArrayGetLBound proc public psa:ptr, nDim:DWORD, plLBound:ptr DWORD

	mov eax,E_INVALIDARG
	@strace <"SafeArrayGetLBound(", psa, ", ", nDim, ", ", plLBound, ")=", eax, " *** unsupp ***">
	ret
	align 4
        
SafeArrayGetLBound  endp

SafeArrayLock proc public psa:ptr

	mov eax,E_INVALIDARG
	@strace <"SafeArrayLock(", psa, ")=", eax, " *** unsupp ***">
	ret
	align 4

SafeArrayLock endp

SafeArrayUnlock proc public psa:ptr

	mov eax,E_INVALIDARG
	@strace <"SafeArrayUnlock(", psa, ")=", eax, " *** unsupp ***">
	ret
	align 4

SafeArrayUnlock endp

SafeArrayAccessData proc public psa:ptr, ppvData:ptr

	mov eax,E_INVALIDARG
	@strace <"SafeArrayAccessData(", psa, ", ", ppvData, ")=", eax, " *** unsupp ***">
	ret
	align 4

SafeArrayAccessData endp

SafeArrayUnaccessData proc public psa:ptr

	mov eax,E_INVALIDARG
	@strace <"SafeArrayUnaccessData(", psa, ")=", eax, " *** unsupp ***">
	ret
	align 4

SafeArrayUnaccessData endp

SafeArrayPtrOfIndex proc public psa:ptr, rgIndices:ptr DWORD, ppvData:ptr ptr

	mov eax,E_INVALIDARG
	@strace <"SafeArrayPtrOfIndex(", psa, ", ", rgIndices, ", ", ppvData, ")=", eax, " *** unsupp ***">
	ret
	align 4
        
SafeArrayPtrOfIndex endp

SafeArrayGetElement proc public psa:ptr, rgIndices:ptr DWORD, pv:ptr

	mov eax,E_INVALIDARG
	@strace <"SafeArrayGetElement(", psa, ", ", rgIndices, ", ", pv, ")=", eax, " *** unsupp ***">
	ret
	align 4
        
SafeArrayGetElement endp

SafeArrayPutElement proc public psa:ptr, rgIndices:ptr DWORD, pv:ptr

	mov eax,E_INVALIDARG
	@strace <"SafeArrayPutElement(", psa, ", ", rgIndices, ", ", pv, ")=", eax, " *** unsupp ***">
	ret
	align 4
        
SafeArrayPutElement endp

SafeArrayRedim proc public psa:ptr, psaboundNew:ptr

	mov eax,E_INVALIDARG
	@strace <"SafeArrayRedim(", psa, ", ", psaboundNew, ")=", eax, " *** unsupp ***">
	ret
	align 4
        
SafeArrayRedim endp

	end
