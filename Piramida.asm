Progr           segment
                assume  cs:Progr, ds:dane, ss:stosik

start:          mov     ax,dane
                mov     ds,ax
                mov     ax,stosik
                mov     ss,ax
                mov     sp,offset szczyt
				
; w tej sekcji inicjujemy calosc, czyli przygotowujemy rejestry, zmienne i wartosci pod czyszczenie ekranu				
zaladujSpacje:
                lea dx,przesuniecie
				mov ax,0b800h  			;początek bloku na pamięć wideo
                mov es,ax				;tworzymy dodatkowy segment wpisując do niego wartosc bazy 0b800h - bo tam bedziemy dzialac
                mov di,0       			;rejestr indeksowy. Może być wykorzystywany jako wstaźnik do adresacji pośredniej, troche jak w C++
                mov al,' '     			;spacja do AL
                mov ah,07d     			;biała litera na czarnym tle - atrybut znaku
				mov cx,2000				;pojemnosc ekranu w ilosci znakow (w dosboxie)

; w tej sekcji czyscimy ekran z uzyciem spacji z poprzedniej sekcji, aby przygotowac sie do rysowania piramidy				
wyczyscEkran:		
				mov es:[di],ax   		;tak jakby [referencja] z C++, na wartosc ze wskaznika (di) po es. Inaczej bysmy dostali wskaznik a nie wartosc, a interesuje nas to drugie. Wstawiamy na zywca do pamieci znak z AX (atrybut+kod). Adresacja POŚREDNIA od segmentu!
				add di,2 				;inkrementujemy co 2, bo jeden znak ma dwa bajty: kolor znaku i jego kod
loop wyczyscEkran 	;teraz uzywamy loopa na ilosc znakow - czyscimy caly ekran
				
				mov di,0				;...i zerujemy wskaznik na ES
				add di,160				;HOTFIX, bo program przeskakiwal o linie nizej po wykonaniu i ucinało szczyt piramidy (bylo od "bbb")
				
;tu rozpoczyna sie wlasciwy program. Potrzebujemy iteracji lecącej od a do z, pionowo
iterPion:
				mov cx,[przesuniecie]	;wpisujemy do cx wartosc przesunięcia kursora
				
;wazna iteracja - przesuwa nam kursor na zadane miejsce!
przesunKursor:
				add di,2				;inkrementujemy di o 2, bo jeden znak sklada sie z atrybutu i kodu znaku (16-bit)
loop przesunKursor						;loopujemy przesuwanie wedlug wartosci [przesuniecie] 
				
				mov cx,[ileLiter]		;zasysamy do cx, ile razy bedziemy wypisywali litere w danym wierszu. Nie moze byc w nastepnej sekcji - bo to niezalezna zmienna i nadpisywalaby sie za kazdym razem
				
;glowna iteracja programu - wypisujemy zadana litere X razy
wypiszLitery:
				mov al,[jakaLitera] 	;wczytujemy z PaO litere do wypisania do al
				mov ah,60h				;do ah wczytujemy atrybut znaku, oryg (czarn-bialy): 0Fh
				mov es:[di],ax			;ladujemy tak skonstruowana pare wprost do pamieci ekranu, z uwzglednieniem biezacego wskaznika di na es
				add di,2				;zapewnia nam tez przesuniecie do nastepnej linii po zakonczonej iteracji, w uzupelnieniu do add di,bx
loop wypiszLitery						;loopujemy wypisanie potrzebna ilosc razy

				add [ileLiter],2		;zwiekszamy ilosc liter do wypisania w nastepnym wierszu o 2 (symetria). 1,3,5,7,9...
				
				mov bx,[pozostaloZnakow] ;ladujemy do bx ilosc niewykorzystanych znakow do konca. Bo musimy wiedziec o ile przesunac di
				shl bx,1			 	 ;znak sklada sie z bajtu atrybutu ORAZ bajtu kodu znaku, czyli musimy pomnozyc ilosc przesuniec di o 2. Przesuniecie logiczne w lewo to nic innego jak pomnozenie liczby przez 2
				add di, bx			 	 ;przesuwamy di "do konca linii" dodajac do niego pozostala ilosc znakow x2
				
				sub [przesuniecie],1 	 ;przesuniecie z wierszem zmniejsza sie o 1
				sub [pozostaloZnakow],1	 ;ilosc pozostalych znakow tez zmniejszy sie o 1 (symetrycznie do przesuniecia)
				sub [ileIterPion],1		 ;ilosc iteracji w pionie tez sie zmniejsza bo wykonalismy wiersz
				
				inc [jakaLitera]		 ;zwiekszamy kod ASCII literki o 1, czyli z 'a' zrobi nam sie 'b' itd
				mov cx,[ileIterPion] 	 ;inicjujemy licznik iteracji w pionie
				loop iterPion			 ;wykonujemy iteracje pionowa
				
;przerwanie konca programu,inaczej nie zakonczy sie poprawnie
      		mov     ah,4ch
	        mov	    al,0
	        int	    21h
Progr           ends

dane            segment
			przesuniecie dw 39  ;39 to kursor na srodku ekranu, 80 pozycji do dyspozycji
			ileIterPion dw 28   ;dw, bo to leci do pary cx na loopa i musi byc do niej dostosowane (16-bit). Liter mamy 26 w alfabecie ang., ale jedna jest juz zaladowana
			ileLiter dw 1		;ile liter w wierszu. Zaczynamy od jednej. Idzie do cx wiec musi byc dw (16-bit)
			jakaLitera db 'a'	;ląduje tylko w al, wiec db (8-bit). Atrybut znaku w ah sie nie zmienia. Zaczynamy od A
			pozostaloZnakow dw 40 ;suma z poczatkowym przesunieciem + znak daje nam pelna linie - 80 znakow
			
dane            ends

stosik          segment
                dw    100h dup(0)
szczyt          Label word
stosik          ends

end start