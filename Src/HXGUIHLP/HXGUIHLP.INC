
;--- keep the menu out of the .ASM source so it is not
;--- in danger catching TABS

msg1a   label byte
        db "ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿"
        db "³ Maximize main window          F3  ³"
        db "³ Send close request to window  F4  ³"
        db "³ Save screen in BMP file       F5  ³"
        db "³ Save main window in BMP file  F6  ³"
        db "³ DOS shell                     F9  ³"
        db "³ Terminate application         F12 ³"
        db "³ Cancel                        ESC ³"
        db "ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ"
MSG1LINES		equ 9
MSG1LINESIZE	equ ($ - msg1a) / MSG1LINES
