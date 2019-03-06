Progr           segment
                assume  cs:Progr, ds:dane, ss:stosik

start:          mov     ax,dane
                mov     ds,ax
                mov     ax,stosik
                mov     ss,ax
                mov     sp,offset szczyt
				
				mov [dlugoscL],0
				mov dlugoscL,0
				
				;TU WPISYWAC KOD!
				jmp init						;pierwsze uruchomienie ---> init
				errZlyZnak:
				mov ah,09h						;funkcja INT (wypisz string z pamieci)
				mov dx,offset nowaLinia			;wrzuca adres ciagu w DS i skacze aż do $
				int 21h
				mov dx,offset bladZlyZnak		;komunikat o przepelnieniu
				int 21h
				poczatek:
				xor di,di						;zerowanie di
				mov cx,5						;iteracja do zerowania tablicy 5elem. w przypadku bledu (za duza liczba, znak zamiast liczby itp)
				zeruj:
				mov tablDec[di],0				;zerowanie po kolejnych indeksach
				inc di
				loop zeruj
				mov [dlugoscL],0				;zerowanie dlugosci liczby
				mov [liczba],0					;zerowanie jesli juz cos zdazylo sie wygenerowac
				mov ah,09h
				mov al,0						;zerowanie al (na wszelki)
				mov dx,offset nowaLinia			;bo ladniej zakonczyc przerywajac linie. Ekwiwalent lea dx,nowaLinia
				int 21h
				init:
			    ;WYPISZ TEKST POWITALNY
				mov ah,09h						;funkcja przerwania int21h:09h - wyswietl lancuch tekstowy
				mov dx,offset podajLiczbeTxt	;wrzuca adres ciągu z DS i "biega" po nim do napotkania sym $
				int 21h							;przerwanie DOS 21h. przerwanie int21h to nic innego jak zestaw gotowych "makr" wykonywanych przez DOS

				;ODCZYTAJ ZNAKI
				mov cx,5						;odczytujemy 5 znakow (bo liczba max 65535), wiec licznik na 5 do readNum
				xor di,di						;shorthand, di==di, wiec ustawi je na (0 XOR 0) = 0 (wyzeruje) - a to di bedzie nam wskazywalo na biezacy indeks tablDec
				
				czytajLiczbe:
				mov ah,01h						;funkcja wczytania znaku z klawiatury z wyswietleniem
				int 21h
				cmp al,13 						;13 to klawisz ENTER
				je klWyj						;jesli koniec liczby potwierdzony enterem, to wyskakujemy z petli do klWyj
				cmp al,57						;porownujemy. Jesli w ASCII wiecej niz 9, to znak nieprawidlowy (litera) - reset programu
				jg errZlyZnak
				cmp al,48						;porownujemy. Jesli w ASCII mniej niz 0, to znak nieprawidlowy (znak specjalny) - reset programu
				jl errZlyZnak
				sub al,'0'						;aby z ASCII zrobić liczbę dziesietnie
				mov tablDec[di],al				;wpisujemy do tablicy tablDec dany znak liczby, na danym jej indeksie (!)
				inc di							;...na kolejne pole tablicy
				inc dlugoscL					;zwiekszamy dlugosc liczby (musimy ja znac)
				loop czytajLiczbe
				; koniec czytajLiczbe


				klWyj:
				dec dlugoscL					;zmniejszamy dlugoscL jak juz skonczylismy bo bylo na wyrost
				js kontynuuj					;jesli flaga znaku =1 (nie ma liczby w ogóle), no to wypiszemy zero i tyle
				
				; konwersja liczby z ciagu do liczby dziesietnej w pamieci
				mov ax,1						;ładujemy 1 do pary AX (fix na pierwsze mnożenie: jedności będą *1)
				mov cx,[dlugoscL]				;ladujemy do CX dlugosc liczby
				inc cx							;zwiekszamy ja o 1
				mov di,[dlugoscL]				;ustawiamy wskaznik na koniec liczby (potem bedzie dekrementowany)
				
				zlozLiczbe:
				xor bx,bx						;bx==0
				mov bl,tablDec[di]				;ladujemy do bl tablice, di wskazuje na max dlugosc liczby, czyli ostatni jej element
				push ax							;ax kopiowane tymczasowo na stos
				mul bx							;mnozenie AX=ax*bx (np. 5 (wczytana)*1 z ax, bo jedności)
				jc przepelnienie				;trigger gdy liczba >=70000 bo przepelnienie wystapi juz tu
				add [liczba],ax					;dodajemy ax do zmiennej liczba (jedn, potem dzies, potem setki itd - kolejne pozycje)
				jc przepelnienie				;trigger gdy liczba >65535 i <70000
				mov ax,[liczba]
				pop ax							;przywracamy ax ze stosu
				mov bx,10						;10 dec do bx
				mul bx							;AX=ax*bx (tak naprawdę, przesuwamy liczbę w lewo robiąc miejsce na dzies/setki/tys. itd)
				dec di							;przesuwamy sie na poprzednia pozycje (10/100/1000 itd)
				loop zlozLiczbe
				jmp kontynuuj					;pomijamy procedure przepelnienia
				
				przepelnienie:
				mov ah,09h						;funkcja INT (wypisz string z pamieci)
				mov dx,offset nowaLinia			;wrzuca adres ciagu w DS i skacze aż do $
				int 21h
				mov dx,offset flagaOverflow		;komunikat o przepelnieniu
				int 21h
				jmp poczatek

				kontynuuj:
				; DEC->BIN
				mov cx,16						;bo zapisujemy 16 bitow
				mov di,15						;zaczynamy od koncowej pozycji
				mov ax,[liczba]					;liczba z pam. do AX. ONA I TAK JEST PRZECHOWYWANA BINARNIE! My tylko chcemy "przechwycic" ten zapis do stringa w pamieci, by moc go wyswietlic.
				doBin:
				mov bx,1						;liczba-szablon; operujemy jedynkami. Na dobry poczatek 0000 0000 0000 0001
				and bx,ax						;maskujemy liczbe. Jesli oba ostatnie bity są jedynkami, to 1, jesli nie - 0. Poczatkowa pozycja: 2^0, potem bedzie porownywana z maska z bx na ostatniej ax 2^1, 2^2 etc...
				cmp bx,1						;uzyskalismy jedynke na ostatniej pozycji? Jesli tak - ustawiamy w szablonie liczby binarnej 1 (poczatkowo 2^0), jesli nie - 0.
				je one
				jne zero
				powrot:
				dec di							;wymusza przejscie na starszy bit w szablonie
				sar ax,1						;przesuwamy arytmetycznie liczbe w prawo, nie tracimy bitu znakowego (0)
				loop doBin

				jmp koniecBin
				one:
				mov binarnie[di],'1'			;na poz. w szablonie wskazana przez di (0...15 (bin)) zapisujemy 1
				jmp powrot
				zero:
				mov binarnie[di],'0'			;na poz. w szablonie wskazana przez di zapisujemy 0
				jmp powrot
				; koniec DEC->BIN

				; wypisz binarnie
				koniecBin:
				mov ah,09h						;funkcja dla INT21, wyswietl lancuch tekstu
				mov dx,offset nowaLinia			;wrzuca adres ciągu w DS i "biega" po nim do napotkania sym $. Tu shorthand dla nowej linii 
				int 21h
				mov dx,offset binarna			;laduje ciag z info o liczbie binarnej			
				int 21h
				mov dx,offset binarnie			;laduje liczbe binarna
				int 21h
				jmp kontynuuj2					;fix - kontynuuj2 zeby pominac errfin1 ktory jest skadsinad
				
				; BIN -> HEX
				kontynuuj2:
				mov cx,4						;bo zapisujemy 4 znaki
				mov di,3						;zaczynamy od ostatniej pozycji
				mov ax,[liczba]					;wczytujemy liczbe (i tak jest ladowana binarnie!)
				doHex:
				mov bx,000fh					;analogicznie do metody bin, tyle ze tu mamy f czyli 1111 na ostatniej czworce
				and bx,ax						;tam gdzie na czworce w ax sa jedynki, maja byc jedynki w bx. gdzie indziej - 0
				cmp bx,10						;uzyskalismy 10 (granica cyfra<->znak)?
				jl cyfry						;NIE: trzeba wpisac cyfre jako reprezentanta czworki binarnej
				jmp znaki						;TAK: litera jako reprezentant czworki binarnej
				powrot2:
				dec di							;zmniejszamy na poprzednia pozycje binarnie w zmiennej 
				sar ax,4						;przesuniecie arytm. w prawo, ale o grupe (4 miejsca bin)
				loop doHex

				jmp koniecHex
				cyfry:
				mov hexalnie[di],bl				;"pozostalosc" po and na 0fh na pozycje w zmiennej, zawsze mniej niż F wiec sie zmiesci
				add hexalnie[di],'0'			;konwersja do ASCII (kod 0 + pozostalosc)
				jmp powrot2

				znaki:
				mov hexalnie[di],bl				;"pozostalosc" po and na 0fh na pozycje w zmiennej, zawsze mniej niz F wiec sie zmiesci
				add hexalnie[di],'A'			;konwersja do ASCII (kod A + pozostalosc)
				sub hexalnie[di],10				;fix zeby powrocic do zakresu, gdy mamy np. 15, to mamy A+15 w ASCII a mamy miec A+5 (F), bo 10 jest juz uwzglednione w samym A!
				jmp powrot2
				koniecHex:
				; koniec DEC -> HEX

				; wypisz HEX
				mov ah,09h						;funkcja INT (wypisz string z pamieci)
				mov dx,offset nowaLinia			;wrzuca adres ciagu w DS i skacze aż do $
				int 21h
				mov dx,offset hexa				;komunikat o hexa
				int 21h
				mov dx,offset hexalnie			;liczba hexadecymalnie
				int 21h
				mov dx,offset nowaLinia			;bo ladniej zakonczyc przerywajac linie
				int 21h
			   
      		mov     ah,4ch
	        mov	    al,0
	        int	    21h
Progr           ends

dane            segment
				tablDec db 0,0,0,0,0					;zmienna z ciągu pojedynczych znakow (tablicowa)
				liczba dw 0
				binarnie db "0000000000000000 bin$"		;szablon dla liczby bin
				hexalnie db "0000 hex$"					;szablon dla liczby hex
				dlugoscL dw 0							;dlugosc liczby
				podajLiczbeTxt db 'Podaj liczbe do konwersji (0-65535): $'
				flagaOverflow db "Liczba poza zakresem!$"
				bladZlyZnak db "Wprowadzono niedozwolony znak!$"
				binarna db 'Liczba bin: $'
				hexa db 'Liczba hex: $'
				nowaLinia db 0ah,0dh,'$'				;shorthand dla nowej linii
dane            ends

stosik          segment
                dw    100h dup(0)
szczyt          Label word
stosik          ends

end start