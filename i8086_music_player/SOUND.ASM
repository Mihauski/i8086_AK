;INTERWALY przy tempo=60 (moderato). 8 = okolo 1 sekundy, 4 = okolo 0,5s
isz equ 2		;szesnastka
ios equ 4		;osemka
icw equ 8		;cwiercnuta
ipo equ 16		;polnuta
ica equ 32		;cala nuta

;WYSOKOSCI dzwiekow (119300/[Hz])

pau	equ 0
;=dw(1193000/[Hz]), 1193000 - sta³a (górna czêst. taktowania) timera 8253, na podstawie której oblicza siê okres drgañ do przes³ania
cn1	equ 36152		; okres drgañ dla dŸwiêku C w oktawie Kontra
dn1 equ 32243
en1 equ 29098
fn1 equ 27114
gn1 equ 24347
an1 equ 21691
hn1 equ 19242
ci1 equ 34086
di1 equ 30590
fi1 equ 25935
gi1 equ 22942
ai1 equ 20569
DosIntr      equ    21h
RetToDos     equ    4ch
Ok	     equ     0h

Progr           segment
                assume  cs:Progr, ds:dane, ss:stosik
start:          mov     ax,dane
                mov     ds,ax
                mov     ax,stosik
                mov     ss,ax
                mov     sp,offset szczyt

		;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		; przykladowy algorytm:																			  ;
		; 1) otwieramy plik																				  ;
		; 2) odczytujemy po jednym znaku skladajac stopniowo kod dzwieku z trzech zmiennych				  ; 
		; 3) odczytujemy po jednym znaku skladajac stopniowo kod interwalu z trzech zmiennych			  ;
		; 4) generujemy zmienne "dzwiek" i "interwal", wykonujemy zagranie								  ;
		; 5) loopujemy odczyt pliku i kroki 2-5															  ;
		; 6) koniec pliku, znak ucieczki, blad = wyjscie												  ;
		;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		cmp byte ptr znak1,'c'
		mov ah, 62h		; "otrzymywanie zawartoœci linii poleceñ" (parametry)
		int 21h
		mov es, bx ; Now ES:0000 -> PSP (program segment prefix) - specjalna, 256-bajtowa przestrzeñ na dodatkowe parametry, w pamieci tu¿ przed programem, generowana przez DOS.
		mov bx, 80h		;poczatek przestrzeni PSP. Pierwsza przestrzeñ
		mov al, es:[bx] ; AL zawiera ilosc znakow ktora wprowadzono jako dodatkowe parametry uruchomieniowe. 81h jest czesto puste (spacja)
		xor cx,cx
		mov cl,al		;zapisujemy sobie  roboczo ilosc znakow
		mov bx,82h ; ES:BX -> kierujemy na poczatek pamieci linii parametrow, pierwszy znak jest w tej komorce
		mov al, es:[bx]
		dec cx		;odczytujemy pierwszy znak samodzielnie bez iteracji wiec o 1 mniej

		lea si,nazwaPliku	;wczytujemy sobie do SI adres zmiennej nazwaPlku
		czytajWejscie:
		mov al, es:[bx]		;...co zeruje nam zawartosc a, wiec musimy pobrac na nowo
		cmp al,0Dh		;w sytuacji, gdy nie mamy zadnego parametru, w tej dodatkowej przestrzeni pierwszy bajt bedzie znakiem 0Dh (enter), bo zatwierdzalismy uruchomienie programu
		je bladPliku	;ale jesli juz jest enter, no to nie ma parametru = wywalamy b³ad (zabezpieczenie przed wyciekiem pamieci)
		xor ah,ah
		mov [si],ax		;zapisujemy znak w dany indeks
		inc si			;zwiekszamy indeks zmiennej zapisu
		inc bx			;zwiekszamy indeks obszaru pamieci (kolejny znak)
		loop czytajWejscie
		
		; OTWIERA PLIK
		mov ah,3Dh			; funkcja DOS int21h: otwórz plik
		mov al,0			; 0 - tylko odczyt, 1 - tylko zapis, 2 - oba
		lea dx,nazwaPliku	; funkcje dosu lubi¹ dx za pointer, to bêdzie wskaznik na znaleziony plik
		int 21h				; wykonujemy odczyt
		jc bladPliku
		mov handler,ax		; int21h zwrocilo nam uchwyt (wygenerowany unikalny ID) do pliku do ax, a my zapisujemy je do zmiennej
		jmp czytajPlik
		
bladPliku:
		mov ah,09h			;wypisz string z pamieci az do napotkania $
		mov dx,offset msgErrPlik	;=== lea dx,msgErrPlik
		int 21h
		jmp koniec
		
czytajPlik:
		; ODCZYTUJE Z PLIKU
		mov ah,3Fh			; funkcja 3Fh odczytuje bajt z pliku
		mov cx,1			; odczytujê po bajcie
		lea dx,bufor	    ; ladujemy stan bufora do dx jako pointer
		mov bx,handler			; uchwyt do pliku do bx
		int 21h				; uruchamiamy odczyt
		jc bladPliku		; fail safe choc nie zdarzylo mi sie
		cmp ax,0			; jesli odczytano nic, to koniec pliku
		jz koniecPliku_up
		
		mov dl,bufor		; ladujemy kod znaku
		cmp dl,' '			; spacje pomijamy jako niegrywalny znak
		je kontynuujOdczyt_up
		cmp dl,0Ah			;CR te¿ (znak nowej linii Linux)
		je kontynuujOdczyt_up
		cmp dl,0Dh			;LF te¿ (znak nowej linii Windows)
		je kontynuujOdczyt_up
		cmp dl,';'			;znacznik koñca melodii
		je koniecPliku_up
		
		cmp ktoryZnak,2		;to 1,2,czy 3 znak slowa?
		jl jestznak1			;znak1: 1 znak nuty lub 1 znak interwalu
		je jestznak2
		jg jestznak3_1			;wywola procedure obslugi obslugi parsowania dzwieku lub interwalu
		
koniecPliku_up:
		jmp koniecPliku

kontynuujOdczyt_up:
		jmp kontynuujOdczyt

		
jestznak1:
		cmp czyInterwal,0	;czy oczekujemy teraz interwalu czy nuty?
		jz sprawdzNute
		jnz sprawdzInterwal
;sprawdzanie poprawnosci pierwszego znaku nuty. Nie chcemy wadliwych plikow muzycznych!
sprawdzNute: ;Mozliwe warianty: c,d,e,f,g,a,h,p (pauza)
			cmp dl,'c'
			je znak1Kontynuuj
			cmp dl,'d'
			je znak1Kontynuuj
			cmp dl,'e'
			je znak1Kontynuuj
			cmp dl,'f'
			je znak1Kontynuuj
			cmp dl,'g'
			je znak1Kontynuuj
			cmp dl,'a'
			je znak1Kontynuuj
			cmp dl,'h'
			je znak1Kontynuuj
			cmp dl,'p'
			je znak1Kontynuuj
			jne errNuta_up			;blad: oczekiwano poprawnej nuty!			
sprawdzInterwal: ;i
			cmp dl,'i'
			jne errInterwal_up		;blad: oczekiwano interwalu!
	znak1Kontynuuj:
			mov znak1,dl			;wepchnij znak w zmienna
			add ktoryZnak,1			;znak1 wczytany, teraz kolej na znak2...
			jmp kontynuujOdczyt		;lecimy do wyswietlenia znaku i potem kolejnej iteracji

errNuta_up:
		jmp errNuta			;skok posredni do errNuta bo poza zakresem dla warunkowego

errInterwal_up:
		jmp errInterwal		;skok posredni do errInterwal bo poza zakresem dla warunkowego
			
jestznak2:
			cmp czyInterwal,0	;czy oczekujemy interwalu?
			jz sprawdzNute2
			jnz sprawdzInterwal2
jestznak3_1:
jmp jestznak3 ;skok posredni dla jestznak3 bo poza zakresem			
			
	sprawdzNute2: ;i,n,a
			cmp dl,'i'			;no to mamy krzyzyk - dopuszczalne
			je znak2Kontynuuj
			cmp dl,'n'			;to mamy nute naturaln¹
			je znak2Kontynuuj
			cmp dl,'a'
			je znak2Kontynuuj
			jne errNuta_up
			
	sprawdzInterwal2: ;s,o,c,p
			cmp dl,'s'
			je znak2Kontynuuj
			cmp dl,'o'
			je znak2Kontynuuj
			cmp dl,'c'
			je znak2Kontynuuj
			cmp dl,'p'
			je znak2Kontynuuj
			jne errInterwal_up
			
	znak2Kontynuuj:
			mov znak2,dl
			add ktoryZnak,1
			jmp kontynuujOdczyt
			
jestznak3:			
			cmp czyInterwal,0	;czy oczekujemy interwalu?
			jz sprawdzNute3
			jnz sprawdzInterwal3
			
	sprawdzNute3: ;1,2,3,4,5,6,7 - oktawy, u - pauza
			cmp dl,'1'
			je znak3Kontynuuj
			cmp dl,'2'
			je znak3Kontynuuj
			cmp dl,'3'
			je znak3Kontynuuj
			cmp dl,'4'
			je znak3Kontynuuj
			cmp dl,'5'
			je znak3Kontynuuj
			cmp dl,'6'
			je znak3Kontynuuj
			cmp dl,'7'
			je znak3Kontynuuj
			cmp dl,'u'
			je znak3Kontynuuj
			jne errNuta
			
	sprawdzInterwal3: ;z,s,w,o,a
			cmp dl,'z'
			je znak3Kontynuuj
			cmp dl,'s'
			je znak3Kontynuuj
			cmp dl,'w'
			je znak3Kontynuuj
			cmp dl,'o'
			je znak3Kontynuuj
			cmp dl,'a'
			je znak3Kontynuuj
			jne errInterwal
	
	znak3Kontynuuj:
			mov znak3,dl
			mov ktoryZnak,1
			
			cmp czyInterwal,0
			PUSH dx			;zeby moglo nam wyswietlic 3 znak, bo nam go CALL zerowal
			jz ustInterwal
			jnz zerInterwal
	ustInterwal:
			CALL ustawDzwiek			;odwolanie do przetwarzania zmiennych znak1,znak2,znak3 do zmiennej dzwiek
			POP dx			;przywracamy znak do wyswietlenia
			mov czyInterwal,1	;byla poprawna nuta? to teraz jej interwal
			jmp kontynuujOdczyt
	zerInterwal:
			CALL ustawInterwal			;odwolanie do przetwarzania zmiennych znak1,znak2,znak3 do zmiennej interwal
			CALL zagraj					;obydwie zmienne przetworzone wiec mozemy je wykorzystac i wyzerowac
			POP dx
			mov czyInterwal,0
			jmp kontynuujOdczyt

kontynuujOdczyt:
		mov al,0			; fix "brudnego rejestru" po wywolywaniu poprzednich CALLi
		CMP dl,1Ah			; czy ctrl-z (koniec pliku)?
		JZ koniecPliku
		mov ah,2			; wypisz pojedynczy znak
		int 21h
jmp czytajPlik		; i znowu czytamy
		
errInterwal:
	mov ah,09h						;funkcja INT (wypisz string z pamieci)
	mov dx,offset nowaLinia			;wrzuca adres ciagu w DS i skacze a¿ do $
	int 21h
	mov dx,offset msgInterwal
	int 21h
	jmp koniec

errNuta:
	mov ah,09h						;funkcja INT (wypisz string z pamieci)
	mov dx,offset nowaLinia			;wrzuca adres ciagu w DS i skacze a¿ do $
	int 21h
	mov dx,offset msgNuta
	int 21h
	jmp koniec
		
koniecPliku:				
		jmp koniec
		
ustawDzwiek:	;ustawia zmienna dzwiek na podstawie zmiennych znak1,znak2,znak3
	xor ax,ax		;zerowanie ax
		cmp byte ptr znak1,'c' ;byte ptr to zastepczy zapis dla adr. posredniej i zapisu [znak3], ze wskazaniem typu: byte. Zapis bezpoœredni (pobranie wartoœci) nie bedzie dzialal, bo znak3 zawiera jedynie WSKAZNIK na dana wartosc w buforze odczytu i to z typu byte, a nie word, stad musimy wziac ten wskaznik i odczytac przypisany do niego bajt, nie inaczej. -- znalezione wyjasnienie
		mov al,'c'
		cmp znak1,al
		jne sprD	;jesli nuta to nie C, no to szukamy innej do przeparsowania...
			cmp byte ptr znak3,'1'		;jesli pierwsza oktawa, to nie trzeba liczyc - mamy okresy zdefiniowane
				jne byloCOblicz
				cmp byte ptr znak2,'i'	;czy bylo Cis (ozn. ci)?
				jne byloCN
				mov dzwiek,ci1			;wczytujemy gotowy dzwiek
				RET
				byloCN:
				cmp byte ptr znak2,'a'	;moze byc dzwiek "pau" majacy druga litere "a", ale to nie tutaj... wtedy wyrzucamy blad
				je errNuta
				mov dzwiek,cn1
				RET						;powracamy z przerwania
				byloCOblicz:		; okres dla liczby o oktawy wyzej, to okres bazowy/2. Dwie oktawy wyzej: /4, trzy: /8 itp itd...
				xor cx,cx	;zerujemy CX
				mov cl,byte ptr znak3	;do cl leci znak informujacy jaka oktawa
				sub cl,'0'	;uzyskujemy wprowadzona liczbe ze znaku ASCII (odejmujemy kod zera)
				sub cl,1	;korekta ilosci petli do wykonania. Jesli cn6, to mamy 1+*5* oktaw
				cmp byte ptr znak2,'i'	;czy bylo cis czy c?
				jne byloCNloop
				mov ax,ci1	;bylo cis? ladujemy okres dla cis1
				jmp liczC
				byloCNloop:
				mov ax,cn1
				liczC:
				shr ax,1	;dzielimy /2 wartosc bazowa (okres) dla najnizszej oktawy danego dzwieku aby uzyskac oktawe wyzej. Tutaj logiczne a nie arytmetyczne - bo zapelnione sa wszystkie wartosci bitowe i powodowalo to bledy (powielalo 1 na najstarszych bitach)
				loop liczC
				mov dzwiek,ax	;po obliczeniu zapisujemy zmienna robocza "dzwiek". Gotowe
				RET
		sprD:
		cmp byte ptr znak1,'d'
		jne sprE
			cmp byte ptr znak3,'1'
				jne byloDOblicz
				cmp byte ptr znak2,'i'
				jne byloDN
				mov dzwiek,di1
				RET
				byloDN:
				cmp byte ptr znak2,'a'
				je errNuta_mid
				mov dzwiek,dn1
				RET
				byloDOblicz:
				xor cx,cx	;zerujemy CX
				mov cl,byte ptr znak3
				sub cl,'0'	;uzyskujemy wprowadzona liczbe
				sub cl,1	;korekta ilosci petli do wykonania. Jesli cn6, to mamy 1+5 oktaw
				cmp byte ptr znak2,'i'
				jne byloDNloop
				mov ax,di1
				jmp liczD
				byloDNloop:
				mov ax,dn1
				liczD:
				shr ax,1	;dzielimy /2 wartosc bazowa (okres) dla najnizszej oktawy danego dzwieku aby uzyskac oktawe wyzej
				loop liczD
				mov dzwiek,ax	;po obliczeniu zapisujemy zmienna "dzwiek". Gotowe
				RET

errNuta_mid:
jmp errNuta
		
		sprE:
		cmp byte ptr znak1,'e'
		jne sprF
				cmp byte ptr znak3,'1'
				jne byloEOblicz
				cmp byte ptr znak2,'i'
				jne byloEN
				mov dzwiek,fn1		;dzwiek eis nie istnieje - to jest f
				RET
				byloEN:
				cmp byte ptr znak2,'a'
				je errNuta_mid
				mov dzwiek,en1
				RET
				byloEOblicz:
				xor cx,cx	;zerujemy CX
				mov cl,byte ptr znak3
				sub cl,'0'	;uzyskujemy wprowadzona liczbe
				sub cl,1	;korekta ilosci petli do wykonania. Jesli cn6, to mamy 1+5 oktaw
				cmp byte ptr znak2,'i'
				jne byloENloop
				mov ax,fn1		;dzwiek eis nie istnieje, to jest f
				jmp liczE
				byloENloop:
				mov ax,en1
				liczE:
				shr ax,1	;dzielimy /2 wartosc bazowa (okres) dla najnizszej oktawy danego dzwieku aby uzyskac oktawe wyzej
				loop liczE
				mov dzwiek,ax	;po obliczeniu zapisujemy zmienna "dzwiek". Gotowe
				RET
		
		sprF:
		cmp byte ptr znak1,'f'
		jne sprG
				cmp byte ptr znak3,'1'
				jne byloFOblicz
				cmp byte ptr znak2,'i'
				jne byloFN
				mov dzwiek,fi1
				RET
				byloFN:
				cmp byte ptr znak2,'a'
				je errNuta_mid
				mov dzwiek,fn1
				RET
				byloFOblicz:
				xor cx,cx	;zerujemy CX
				mov cl,byte ptr znak3
				sub cl,'0'	;uzyskujemy wprowadzona liczbe
				sub cl,1	;korekta ilosci petli do wykonania. Jesli cn6, to mamy 1+5 oktaw
				cmp byte ptr znak2,'i'
				jne byloFNloop
				mov ax,fi1
				jmp liczF
				byloFNloop:
				mov ax,fn1
				liczF:
				shr ax,1	;dzielimy /2 wartosc bazowa (okres) dla najnizszej oktawy danego dzwieku aby uzyskac oktawe wyzej
				loop liczF
				mov dzwiek,ax	;po obliczeniu zapisujemy zmienna "dzwiek". Gotowe
				RET

		sprG:
		cmp byte ptr znak1,'g'
		jne sprA
				cmp byte ptr znak3,'1'
				jne byloGOblicz
				cmp byte ptr znak2,'i'
				jne byloGN
				mov dzwiek,gi1
				RET
				byloGN:
				cmp byte ptr znak2,'a'
				je errNuta_down
				mov dzwiek,gn1
				RET
				byloGOblicz:
				xor cx,cx	;zerujemy CX
				mov cl,byte ptr znak3
				sub cl,'0'	;uzyskujemy wprowadzona liczbe
				sub cl,1	;korekta ilosci petli do wykonania. Jesli cn6, to mamy 1+5 oktaw
				cmp byte ptr znak2,'i'
				jne byloGNloop
				mov ax,gi1
				jmp liczG
				byloGNloop:
				mov ax,gn1
				liczG:
				shr ax,1	;dzielimy /2 wartosc bazowa (okres) dla najnizszej oktawy danego dzwieku aby uzyskac oktawe wyzej
				loop liczG
				mov dzwiek,ax	;po obliczeniu zapisujemy zmienna "dzwiek". Gotowe
				RET
		
		sprA:
		cmp byte ptr znak1,'a'
		jne sprH
				cmp byte ptr znak3,'1'
				jne byloAOblicz
				cmp byte ptr znak2,'i'
				jne byloAN
				mov dzwiek,ai1
				RET
				byloAN:
				cmp byte ptr znak2,'a'
				je errNuta_down
				mov dzwiek,an1
				RET
				
				byloAOblicz:
				xor cx,cx	;zerujemy CX
				mov cl,byte ptr znak3
				sub cl,'0'	;uzyskujemy wprowadzona liczbe
				sub cl,1	;korekta ilosci petli do wykonania. Jesli cn6, to mamy 1+5 oktaw
				cmp byte ptr znak2,'i'
				jne byloANloop
				mov ax,ai1
				jmp liczA
				byloANloop:
				mov ax,an1
				liczA:
				shr ax,1	;dzielimy /2 wartosc bazowa (okres) dla najnizszej oktawy danego dzwieku aby uzyskac oktawe wyzej
				loop liczA
				mov dzwiek,ax	;po obliczeniu zapisujemy zmienna "dzwiek". Gotowe
				RET
				
errnuta_down:
jmp errNuta		;skok posredni do errNuta bo poza zakresem dla skokow warunkowych
		
		sprH:
		cmp byte ptr znak1,'h'
		jne sprP
				cmp byte ptr znak3,'1'
				jne byloHOblicz
				cmp byte ptr znak2,'i'
				jne byloHN
				je byloHOblicz		;wyjatek - his nie istnieje, to jest C z wyzszej oktawy!
				byloHN:
				cmp byte ptr znak2,'a'
				je errNuta_down
				mov dzwiek,hn1
				RET
				byloHOblicz:
				xor cx,cx	;zerujemy CX
				mov cl,byte ptr znak3
				sub cl,'0'	;uzyskujemy wprowadzona liczbe
				sub cl,1	;korekta ilosci petli do wykonania. Jesli cn6, to mamy 1+5 oktaw
				cmp byte ptr znak2,'i'
				jne byloHNloop
				mov ax,cn1	;wyjatek - musimy zaladowac c bo to jest odpowiednik his...
				add cl,1	;...i podbic je o oktawe wyzej, bo his5 === c6
				jmp liczH
				byloHNloop:
				mov ax,hn1
				liczH:
				shr ax,1	;dzielimy /2 wartosc bazowa (okres) dla najnizszej oktawy danego dzwieku aby uzyskac oktawe wyzej
				loop liczH
				mov dzwiek,ax	;po obliczeniu zapisujemy zmienna "dzwiek". Gotowe
				RET
				
errInterwal_down:
jmp errInterwal		;skok posredni do errInterwal, bo poza zakresem			
		
		sprP:
		cmp byte ptr znak1,'p'
				cmp byte ptr znak2,'a'
				jne errNuta_down
				cmp byte ptr znak3,'u'
				jne errNuta_down
				mov dzwiek,pau
				RET

ustawInterwal:	;ustawia zmienna interwal na podstawie zmiennych znak2,znak3 (znak1 zawsze ten sam i sprawdzony wczesniej)
		cmp byte ptr znak2,'s' ;s,o,c,p
		jne sprawdzIO
				cmp byte ptr znak3,'z'
				jne errInterwal_down
				mov interwal,isz
				RET
		
		sprawdzIO:
		cmp byte ptr znak2,'o'
		jne sprawdzIC
				cmp byte ptr znak3,'s'
				jne errInterwal_down
				mov interwal,ios
				RET
		
		sprawdzIC:
		cmp byte ptr znak2,'c'
		jne sprawdzIP ;w,a
				cmp byte ptr znak3,'w'
				jne sICa
				mov interwal,icw
				RET
				sICa:
				cmp byte ptr znak3,'a'
				jne errInterwal_down
				mov interwal,ica
				RET
		
		sprawdzIP:
		cmp byte ptr znak2,'p'
				cmp byte ptr znak3,'o'
				jne errInterwal_down
				mov interwal,ipo
				RET

;Procedura wywo³ujaca zagranie dzwieku lub pauzy (rozrozniajaca)				
zagraj:
	cmp dzwiek,0	;pauza ma czestotliwosc oraz okres = 0
	je zagrajPauze
	jne zagrajDzwiek
	RET

	; uklady 8253 8255
zagrajDzwiek:
		mov	ax,dzwiek		; laduje dw z czestotliwoscia do ax
		out	42h,al			; wysyla na port oscylatora 8253 mlodsza czesc okresu
		mov	al,ah			;laduje starsza czesc do al
		out	42h,al			; ...i wysy³a starsz¹ czesc (8253 ma 16-bitowe slowa sterujace i "wie" ze taka jest kolejnosc wysylu)
		;8253 ma bezposrednie polaczenie z glosnikiem i moze nim sterowac!
		
		in 	al,61h			; odczytujemy stan glosnika
		or	al,00000011b	; wlaczamy go (dwa ostatnie bity na 1)
		out	61h,al			; ...i odsylamy polecenie wlaczenia. W tej chwili zaczyna nam grac az go nie wylaczymy bo wciaz generowany jest impuls

		
		;funkcja czekaj¹ca okreœlony czas ("zawieszenie" programu na zadany interwal)
		xor	dx,dx			; zerujemy dx
		mov	cx,interwal		; ladujemy do cx zadany interwal		
		mov	ah,86h	;czekaj okreslony w cx interwal w milisekundach - funkcja przerwania bios
		int	15h		;przerwanie bios. >generuje czasem illegal read/write - bug DosBOX-a. https://stackoverflow.com/questions/43194265/dosbox-is-buggy-with-int-15h-ah-86h ; ale dzia³a poprawnie

		in 	al,61h
		and	al,11111100b	; wylaczamy glosnik - zawsze!
		out	61h,al
		RET					; dzwiek odegrany. powrot do procedury wywolujacej
		
zagrajPauze:
		;uruchamiajac to zakladamy i wiemy, ze glosnik jest juz aktualnie wylaczony
		xor	dx,dx
		mov	cx,interwal ; dlugosc trwania pauzy (wylaczonego glosnika)		
		mov	ah,86h
		int	15h
		RET
		
koniec:
        mov ah,RetToDos
		mov	al,Ok	;zeruje al
		int	DosIntr	;21h
Progr           ends

dane            segment
dzwiek dw ?
interwal dw ?

nowaLinia db 0ah,0dh,'$'				;shorthand dla nowej linii
msgNuta db 'Blad: spodziewano sie poprawnej nuty!$'
msgInterwal db 'Blad: spodziewano sie poprawnego interwalu!$'
msgErrPlik db 'Blad: brak takiego pliku lub nie podano jego nazwy jako parametru uruchomienia!$'

ktoryZnak db 1
znak1 db ?
znak2 db ?
znak3 db ?
czyInterwal db 0
nazwaPliku db 10 dup(0)
;nazwaPliku db 'melodia.txt',0	; zmienna przechowujaca nazwe pliku, tak jest latwiej. I druga wartosc tablicy to 0
handler dw ?					; handler (uchwyt) do pliku. Tutaj dos przypisuje sobie unikalny ID otwartego pliku
bufor db ? 			; pusty bufor znaków
temp dw ?
dane            ends


stosik          segment
                dw    100h dup(0)
szczyt          Label word
stosik          ends


end start