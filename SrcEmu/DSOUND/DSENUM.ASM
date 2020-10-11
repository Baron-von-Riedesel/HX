
;--- implements DirectSoundEnumerateA()

        .386
if ?FLAT        
        .MODEL FLAT, stdcall
else
        .MODEL SMALL, stdcall
endif
        option casemap:none
        option proc:private

		include winbase.inc
        include dsound.inc
        include mmsystem.inc
        include macros.inc

protoDSEnumCallback typedef proto stdcall :dword, :dword, :dword, :dword
LPDSENUMCALLBACK typedef ptr protoDSEnumCallback

		.CONST
        
guidDS	GUID <00000001, 0002, 0003, <0, 0, 0, 0, 0, 0, 0, 0>>        

        .CODE

DirectSoundEnumerateA proc public lpDSEnumCallback:LPDSENUMCALLBACK, lpContext:dword
		invoke	waveOutGetNumDevs
        jz done
        invoke lpDSEnumCallback, offset guidDS, CStr("hx DS emulation"), \
        	CStr("dsound"), lpContext
done:        
		mov eax, DS_OK
		@strace	<"DirectSoundEnumerateA(", lpDSEnumCallback, ", ", lpContext, ")=", eax>
		ret
        align 4
DirectSoundEnumerateA endp

        END

