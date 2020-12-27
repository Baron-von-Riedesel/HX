
;--- locale definitions that DOS won't supply
;--- used by GetLocal.asm

senglanguage db "English",0	;english name of language
sengcountry  db "England",0	;english name of country

sdaynames    db "Monday",0
             db "Tuesday",0
             db "Wednesday",0
             db "Thursday",0
             db "Friday",0
             db "Saturday",0
             db "Sunday",0
smonthnames  db "January",0
             db "February",0
             db "March",0
             db "April",0
             db "May",0
             db "June",0
             db "July",0
             db "August",0
             db "September",0
             db "October",0
             db "November",0
             db "December",0

stimeformat  db "HH:mm:ss",0
sshortdate   db "dd.MM.yyyy",0
ilanguage    dd 9			;language english
icalendartype dd CAL_GREGORIAN

