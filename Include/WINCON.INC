
FOREGROUND_BLUE      = 00001h ;// text color contains blue.
FOREGROUND_GREEN     = 00002h ;// text color contains green.
FOREGROUND_RED       = 00004h ;// text color contains red.
FOREGROUND_INTENSITY = 00008h ;// text color is intensified.
BACKGROUND_BLUE      = 00010h ;// background color contains blue.
BACKGROUND_GREEN     = 00020h ;// background color contains green.
BACKGROUND_RED       = 00040h ;// background color contains red.
BACKGROUND_INTENSITY = 00080h ;// background color is intensified.
BACKGROUND_CYAN      = 00030h


FOREGROUND_WHITE = FOREGROUND_BLUE or FOREGROUND_GREEN or FOREGROUND_RED
FOREGROUND_BLACK = 0
FOREGROUND_YELLOW = FOREGROUND_GREEN or FOREGROUND_RED
BACKGROUND_WHITE = BACKGROUND_BLUE or BACKGROUND_GREEN or BACKGROUND_RED
BACKGROUND_BLACK = 0

CTRL_C_EVENT        equ 0
CTRL_BREAK_EVENT    equ 1
CTRL_CLOSE_EVENT    equ 2
CTRL_LOGOFF_EVENT   equ 5
CTRL_SHUTDOWN_EVENT equ 6


ENABLE_PROCESSED_INPUT equ 00001h
ENABLE_LINE_INPUT      equ 00002h
ENABLE_ECHO_INPUT      equ 00004h
ENABLE_WINDOW_INPUT    equ 00008h
ENABLE_MOUSE_INPUT     equ 00010h
ENABLE_PROCESSED_OUTPUT equ 00001h

ATTACH_PARENT_CONSOLE	equ -1


CHARTYPE UNION
 UnicodeChar    WORD ?
 AsciiChar      db ?
CHARTYPE ENDS

CHAR_INFO STRUCT
Char          CHARTYPE <>
Attributes    WORD      ?
CHAR_INFO ENDS

CONSOLE_SCREEN_BUFFER_INFO struct
dwSize           COORD <>
dwCursorPosition COORD <>
wAttributes      dw ?
srWindow         SMALL_RECT <?,?,?,?>
dwMaximumWindowSize dd ?
CONSOLE_SCREEN_BUFFER_INFO ends

KEY_EVENT_RECORD struct
bKeyDown          dd ?
wRepeatCount      dw ?
wVirtualKeyCode   dw ?
wVirtualScanCode  dw ?
AsciiChar         dw ?
dwControlKeyState dd ?
KEY_EVENT_RECORD ends

MOUSE_EVENT_RECORD struct
dwMousePosition   dd ?           ;word x,word y
dwButtonState     dd ?
dwControlKeyState dd ?
dwEventFlags      dd ?
MOUSE_EVENT_RECORD ends

INPUT_RECORD struct
EventType	dw ?
res			dw ?
union Event
KeyEvent	KEY_EVENT_RECORD <>
MouseEvent	MOUSE_EVENT_RECORD <>
ends                
INPUT_RECORD ends

; ControlKeyState flags

RIGHT_ALT_PRESSED  equ   0001h ;/ the right alt key is pressed.
LEFT_ALT_PRESSED   equ   0002h ;/ the left alt key is pressed.
RIGHT_CTRL_PRESSED equ   0004h ;/ the right ctrl key is pressed.
LEFT_CTRL_PRESSED  equ   0008h ;/ the left ctrl key is pressed.
SHIFT_PRESSED      equ   0010h ;/ the shift key is pressed.
NUMLOCK_ON         equ   0020h ;/ the numlock light is on.
SCROLLLOCK_ON      equ   0040h ;/ the scrolllock light is on.
CAPSLOCK_ON        equ   0080h ;/ the capslock light is on.
ENHANCED_KEY       equ   0100h ;/ the key is enhanced.

ALT_PRESSED        equ LEFT_ALT_PRESSED or RIGHT_ALT_PRESSED
CTRL_PRESSED       equ LEFT_CTRL_PRESSED or RIGHT_CTRL_PRESSED

FROM_LEFT_1ST_BUTTON_PRESSED equ 0001h
RIGHTMOST_BUTTON_PRESSED     equ 0002h
FROM_LEFT_2ND_BUTTON_PRESSED equ 0004h
FROM_LEFT_3RD_BUTTON_PRESSED equ 0008h
FROM_LEFT_4TH_BUTTON_PRESSED equ 0010h

;*** input event types ***

KEY_EVENT       equ 1
MOUSE_EVENT     equ 2

;*** mouse event flags ***

MOUSE_MOVED   equ 0001h
DOUBLE_CLICK  equ 0002h
MOUSE_WHEELED equ 0004h

CONSOLE_CURSOR_INFO   struct
dwSize   dd ?
bVisible dd ?
CONSOLE_CURSOR_INFO   ends

ifdef _KERNEL32_
?INDCALL_ = 0
elseif ?INDCALL eq 0
?INDCALL_ = 0
else
?INDCALL_ = 1
endif

if ?INDCALL_ eq 0

AllocConsole			     proto near stdcall
FillConsoleOutputAttribute   proto near stdcall :dword, :dword, :dword, :COORD, :ptr dword
FillConsoleOutputCharacterA  proto near stdcall :dword, :dword, :dword, :COORD, :ptr dword
FlushConsoleInputBuffer      proto near stdcall :dword
FreeConsole			  	     proto near stdcall
GetConsoleCursorInfo         proto near stdcall :dword, :ptr CONSOLE_CURSOR_INFO
GetConsoleMode               proto near stdcall :dword, :ptr dword
GetConsoleScreenBufferInfo   proto near stdcall :dword, :ptr CONSOLE_SCREEN_BUFFER_INFO
GetLargestConsoleWindowSize  proto near stdcall :dword
GetNumberOfConsoleInputEvents proto near stdcall :dword, :dword
GetStdHandle                 proto near stdcall :dword
PeekConsoleInputA            proto near stdcall :dword, :ptr INPUT_RECORD, :dword, :ptr dword
ReadConsoleA                 proto near stdcall :dword, :ptr BYTE, :dword,:ptr dword, :dword
ReadConsoleInputA            proto near stdcall :dword, :ptr INPUT_RECORD, :dword, :ptr dword
ReadConsoleOutputA           proto near stdcall :dword, :ptr CHAR_INFO, :COORD, :COORD, :ptr SMALL_RECT
ReadConsoleOutputCharacterA  proto near stdcall :dword, :ptr BYTE, :dword, :COORD, :ptr dword
ScrollConsoleScreenBufferA   proto near stdcall :dword, :ptr SMALL_RECT, :ptr SMALL_RECT, :COORD, :ptr CHAR_INFO
SetConsoleActiveScreenBuffer proto near stdcall :dword
SetConsoleCtrlHandler        proto near stdcall :ptr, :dword
SetConsoleCursorInfo         proto near stdcall :dword, :ptr CONSOLE_CURSOR_INFO
SetConsoleCursorPosition     proto near stdcall :dword, :COORD
SetConsoleMode               proto near stdcall :dword, :dword
SetConsoleWindowInfo         proto near stdcall :dword, :dword, :dword
SetConsoleScreenBufferSize   proto near stdcall :dword, :COORD
WriteConsoleA                proto near stdcall :dword, :ptr BYTE, :dword, :ptr dword, :dword
WriteConsoleInputA           proto near stdcall :dword, :ptr INPUT_RECORD, :dword, :ptr dword
WriteConsoleOutputA          proto near stdcall :dword, :ptr CHAR_INFO, :COORD, :COORD, :ptr SMALL_RECT
WriteConsoleOutputCharacterA proto near stdcall :dword, :ptr BYTE, :dword, :COORD, :ptr dword

else

;	.DATA
_DATA segment

externdef stdcall _imp__AllocConsole@0                  :pfunc@0
externdef stdcall _imp__FillConsoleOutputAttribute@20   :pfunc@20
externdef stdcall _imp__FillConsoleOutputCharacterA@20  :pfunc@20
externdef stdcall _imp__FlushConsoleInputBuffer@4       :pfunc@4
externdef stdcall _imp__FreeConsole@0                   :pfunc@0
externdef stdcall _imp__GenerateConsoleCtrlEvent@8      :pfunc@8
externdef stdcall _imp__GetConsoleCursorInfo@8          :pfunc@8
externdef stdcall _imp__GetConsoleMode@8                :pfunc@8
externdef stdcall _imp__GetConsoleScreenBufferInfo@8    :pfunc@8
externdef stdcall _imp__GetLargestConsoleWindowSize@4   :pfunc@4
externdef stdcall _imp__GetNumberOfConsoleInputEvents@8 :pfunc@8
externdef stdcall _imp__GetStdHandle@4                  :pfunc@4
externdef stdcall _imp__PeekConsoleInputA@16            :pfunc@16
externdef stdcall _imp__ReadConsoleA@20                 :pfunc@20
externdef stdcall _imp__ReadConsoleInputA@16            :pfunc@16
externdef stdcall _imp__ReadConsoleOutputA@20           :pfunc@20
externdef stdcall _imp__ReadConsoleOutputCharacterA@20  :pfunc@20
externdef stdcall _imp__ScrollConsoleScreenBufferA@20   :pfunc@20
externdef stdcall _imp__SetConsoleCtrlHandler@8         :pfunc@8
externdef stdcall _imp__SetConsoleCursorInfo@8          :pfunc@8
externdef stdcall _imp__SetConsoleCursorPosition@8      :pfunc@8
externdef stdcall _imp__SetConsoleMode@8                :pfunc@8
externdef stdcall _imp__SetConsoleWindowInfo@12         :pfunc@12
externdef stdcall _imp__SetConsoleScreenBufferSize@8    :pfunc@8
externdef stdcall _imp__WriteConsoleA@20                :pfunc@20
externdef stdcall _imp__WriteConsoleInputA@16           :pfunc@16
externdef stdcall _imp__WriteConsoleOutputA@20          :pfunc@20
externdef stdcall _imp__WriteConsoleOutputCharacterA@20 :pfunc@20

_DATA ends

AllocConsole                 equ <_imp__AllocConsole@0>
FillConsoleOutputAttribute   equ <_imp__FillConsoleOutputAttribute@20>
FillConsoleOutputCharacterA  equ <_imp__FillConsoleOutputCharacterA@20>
FlushConsoleInputBuffer      equ <_imp__FlushConsoleInputBuffer@4>
FreeConsole                  equ <_imp__FreeConsole@0>
GenerateConsoleCtrlEvent     equ <_imp__GenerateConsoleCtrlEvent@8>
GetConsoleCursorInfo         equ <_imp__GetConsoleCursorInfo@8>
GetConsoleMode               equ <_imp__GetConsoleMode@8>
GetConsoleScreenBufferInfo   equ <_imp__GetConsoleScreenBufferInfo@8>
GetLargestConsoleWindowSize  equ <_imp__GetLargestConsoleWindowSize@4>
GetNumberOfConsoleInputEvents equ <_imp__GetNumberOfConsoleInputEvents@8>
GetStdHandle                 equ <_imp__GetStdHandle@4>
PeekConsoleInputA            equ <_imp__PeekConsoleInputA@16>
ReadConsoleA                 equ <_imp__ReadConsoleA@20>
ReadConsole                  equ <_imp__ReadConsoleA@20>
ReadConsoleInputA            equ <_imp__ReadConsoleInputA@16>
ReadConsoleOutputA           equ <_imp__ReadConsoleOutputA@20>
ReadConsoleOutputCharacterA  equ <_imp__ReadConsoleOutputCharacterA@20>
ScrollConsoleScreenBufferA   equ <_imp__ScrollConsoleScreenBufferA@20>
SetConsoleCtrlHandler        equ <_imp__SetConsoleCtrlHandler@8>
SetConsoleCursorInfo         equ <_imp__SetConsoleCursorInfo@8>
SetConsoleCursorPosition     equ <_imp__SetConsoleCursorPosition@8>
SetConsoleMode               equ <_imp__SetConsoleMode@8>
SetConsoleWindowInfo         equ <_imp__SetConsoleWindowInfo@12>
SetConsoleScreenBufferSize   equ <_imp__SetConsoleScreenBufferSize@8>
WriteConsoleA                equ <_imp__WriteConsoleA@20>
WriteConsoleInputA           equ <_imp__WriteConsoleInputA@16>
WriteConsoleOutputA          equ <_imp__WriteConsoleOutputA@20>
WriteConsoleOutputCharacterA equ <_imp__WriteConsoleOutputCharacterA@20>

endif

FillConsoleOutputCharacter	textequ <FillConsoleOutputCharacterA>
PeekConsoleInput			textequ <PeekConsoleInputA>
ReadConsole					textequ <ReadConsoleA>
ReadConsoleInput			textequ <ReadConsoleInputA>
ReadConsoleOutput			textequ <ReadConsoleOutputA>
ReadConsoleOutputCharacter	textequ <ReadConsoleOutputCharacterA>
ScrollConsoleScreenBuffer	textequ <ScrollConsoleScreenBufferA>
WriteConsole				textequ <WriteConsoleA>
WriteConsoleInput			textequ <WriteConsoleInputA>
WriteConsoleOutput			textequ <WriteConsoleOutputA>
WriteConsoleOutputCharacter	textequ <WriteConsoleOutputCharacterA>

if 0
@GetStdHandle macro typ
          invoke  GetStdHandle,typ
          endm

@GetConsoleScreenBufferInfo macro handle,pScreenbuffinfo
          invoke  GetConsoleScreenBufferInfo,handle,pScreenbuffinfo
          endm

@GetLargestConsoleWindowSize macro handle
          invoke  GetLargestConsoleWindowSize,handle
          endm

@GetNumberOfConsoleInputEvents macro handle,pEvents
          invoke  GetNumberOfConsoleInputEvents,handle,pEvents
          endm

@SetConsoleWindowInfo macro handle,flag,pRect
          invoke  SetConsoleWindowInfo,handle,flag,pRect
          endm

@SetConsoleScreenBufferSize macro handle,newSize
          invoke  SetConsoleScreenBufferSize,handle,newSize
          endm

@WriteConsole macro handle,pChar,dwLength,pWritten
          invoke  WriteConsoleA,handle,pChar,dwLength,pWritten,0
          endm

@WriteConsoleOutput macro handle,pBuff,buffrect,coord,pDescRect
          invoke  WriteConsoleOutputA,handle,pBuff,buffrect,coord,pDescRect
          endm

@ReadConsoleOutput macro handle,pBuff,buffrect,coord,pDescRect
          invoke  ReadConsoleOutputA,handle,pBuff,buffrect,coord,pDescRect
          endm

@WriteConsoleOutputCharacter macro handle,pChar,dwLength,coord,pWritten
          invoke  WriteConsoleOutputCharacterA,handle,pChar,dwLength,coord,pWritten
          endm

@GetConsoleMode macro handle,lpmode
          invoke  GetConsoleMode,handle,lpmode
          endm

@SetConsoleMode macro handle,typ
          invoke  SetConsoleMode,handle,typ
          endm

@ReadConsole macro handle,pBuffer,dwLength,pCharsRead,reserved
          invoke  ReadConsoleA,handle,pBuffer,dwLength,pCharsRead,reserved
          endm

@PeekConsoleInput macro handle,pBuffer,dwLength,pEventsread
          invoke  PeekConsoleInputA,handle,pBuffer,dwLength,pEventsread
          endm

@ReadConsoleInput macro handle,pBuffer,dwLength,pEventsread
          invoke  ReadConsoleInputA,handle,pBuffer,dwLength,pEventsread
          endm

@FillConsoleOutputAttribute macro handle,attribute,dwLength,coord,pWritten
          invoke  FillConsoleOutputAttribute,handle,attribute,dwLength,coord,pWritten
          endm

@FillConsoleOutputCharacter macro handle,character,dwLength,coord,pWritten
          invoke  FillConsoleOutputCharacterA,handle,character,dwLength,coord,pWritten
          endm

@ScrollConsoleScreenBuffer macro handle,pRect,pClipRect,coord,pFillCell
          invoke  ScrollConsoleScreenBufferA,handle,pRect,pClipRect,coord,pFillCell
          endm

@SetConsoleCursorInfo macro handle,pInfo
        invoke SetConsoleCursorInfo,handle,pInfo
        endm

@GetConsoleCursorInfo macro handle,pInfo
        invoke GetConsoleCursorInfo,handle,pInfo
        endm

@SetConsoleCursorPosition macro handle,pos
        invoke SetConsoleCursorPosition,handle,pos
        endm
endif

        include vk.inc

