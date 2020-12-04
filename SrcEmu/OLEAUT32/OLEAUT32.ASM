
        .386
        .MODEL FLAT, stdcall

        .DATA

        .CODE

DllMain proc stdcall public handle:dword,reason:dword,reserved:dword

;        int     3
        mov     eax,1
        ret
DllMain endp

        END DllMain

