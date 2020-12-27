
;*** common macros for function definitions 32-Bit ***

;    @prolog16     : standard prologue for DPMI-16
;    @loadesp      : load a register with value of (e)sp
;    @loadebp      : load ebp with value of (e)sp
;    @push         ; obsolete: like push, increments ?ESPOFS
;    @pop          ; obsolete: like pop, decrements ?ESPOFS


ifndef FUNCTION_DEFINED

FUNCTION_DEFINED equ 1

ifndef ?FORCEFRAME
?FORCEFRAME = 0
endif

        include stddefs.inc

if ?DPMI16

@prologue macro procname,flag,parmbyte,localbyte,reglist,userparms

    if flag
      if parmbyte + localbyte
        push    ebp
        movzx   ebp,sp
      endif
      if localbyte
        add     esp,-localbyte
      endif
    endif
    for r,reglist
       push r
    endm
        exitm %localbyte
endm

OPTION PROLOGUE: @prologue

else

@prologue equ <prologuedef>

endif

;* prologue for structured exception handling

@sehprologue macro procname,flag,parmbyte,localbyte,reglist,userparms

      db      64h
      mov     eax, DWORD PTR ds:__except_list
      push    ebp
      mov     ebp,esp
      push    -1                                      ;ebp-4]
      push    userparms                               ;[ebp-8]
      push    OFFSET FLAT:__except_handler3           ;[ebp-12]
      push    eax                                     ;[ebp-16]
      db      64h
      mov     DWORD PTR ds:__except_list, esp         ;ebp-16

        add     esp,-localbyte-3*4

      for r,reglist
        push r
      endm
      mov      [ebp-24],esp         ;esp sichern

        exitm %localbyte+4*4+3*4
endm

@sehepilogue macro procname,flag,parmbyte,localbyte,reglist,userparms


        mov     ecx,[ebp-16]
        db 64h
        mov     DWORD PTR ds:__except_list, ecx
        for r,reglist
         pop r
        endm
        mov     esp, ebp
        pop     ebp
        ret     parmbyte
endm

@loadesp macro x
if ?DPMI16
        movzx x,sp
else
        mov x,esp
endif
        endm

@loadebp macro
        @loadesp ebp
        endm

@push   macro x
        push x
?ESPOFS = ?ESPOFS + 4
        endm

@pop    macro x
        pop  x
?ESPOFS = ?ESPOFS - 4
        endm

endif

