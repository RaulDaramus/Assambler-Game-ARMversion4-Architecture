		            AREA datos,DATA
;Variables principales del programa
reloj               DCD 0                   ;contador de centesimas de segundo movimiento
reloj_fin           DCD 0                   ;contador de centesimas de segundo tiempo sin capturar ningun simbolo
max                 DCD 8                   ;velocidad de movimiento (en centesimas s.)
cont                DCD 8                   ;instante siguiente movimiento
cont_simbolo        DCD 512                 ;instante siguiente aparicion simbolo
dirx                DCD 0                   ;direccion mov. caracter ‘#’ (-1 izda.,0 stop,1 der.)
diry                DCD 0                   ;direccion mov. caracter ‘#’ (-1 arriba,0 stop,1 abajo)
fin                 DCB 0                   ;indicador fin de programa (si vale 1)
;interrupciones IRQ
ICBaseEnabl	        EQU 0xFFFFF000			;base para activar IRQ
VICIntEnable 	    EQU 0xFFFFF010          ;activar IRQs (solo bits 1)
VICIntEnClr 	    EQU 0xFFFFF014			;desactivar IRQs (solo bits 1)
VICVectAddr0	    EQU 0xFFFFF100          ;Registro con la @ de la 1º instr de la RSI_IRQ0 vectorizada
VICVectAddr		    EQU	0xFFFFF030	        ;Registro @VI
IntEnableOffset	    EQU 0x10				;selecciona activar IRQ4
IRQ_Index_timer     EQU 4			   	    ;Nº de IRQ del Timer0
IRQ_Index_tec 	    EQU 7			   	    ;Nº de IRQ del teclado
T0_IR			    EQU 0xE0004000          ;reg. para bajar peticiones IRQ4
TEC_DAT 		    EQU 0xE0010000	        ;reg. datos teclado UART11
I_Bit               EQU 0x80                ;si I bit = 1 => IRQ = 0
;pantalla
alto                EQU 16                  ; alto de la pantalla
ancho               EQU 32                  ; ancho de la pantalla
fila                DCD 0                   ; variable auxiliar para detectar la llegada al extremo de la pantalla
columna             DCD 0                  ; variable auxiliar para detectar la llegada al extremo de la pantalla
pantalla            EQU 0x40007E00          ; direccion principal de la pantalla
dir_posicion        DCD 0                   ; punto medio de la pantalla
;codigos ASCII
espacio             EQU 32                  ; codigo ASCII -> " "
jugador             EQU 35                  ; codigo ASCII -> "#"
simbolo             EQU 36                  ; codigo ASCII -> "$"
arriba              EQU 73                  ; codigo ASCII -> "I"
arriba_min          EQU 105                 ; codigo ASCII -> "i"
izquierda           EQU 74                  ; codigo ASCII -> "J"
izquierda_min       EQU 106                 ; codigo ASCII -> "j"
abajo               EQU 75                  ; codigo ASCII -> "K"
abajo_min           EQU 107                 ; codigo ASCII -> "k"
derecha             EQU 76                  ; codigo ASCII -> "L"
derecha_min         EQU 108                 ; codigo ASCII -> "l"
aumentar            EQU 43                  ; codigo ASCII -> "+"
disminuir           EQU 45                  ; codigo ASCII -> "-"
acabar              EQU 81                  ; codigo ASCII -> "Q"
acabar_min          EQU 113                 ; codigo ASCII -> "q"
;semilla
semilla             EQU 511                 ; valor maximo para generar numeros (0-511)
;velocidad
velocidad_maxima    DCD 1                   ; 1 centesima de segundo para el movimiento
velocidad_minima    DCD 124                 ; 124 centesimas de segundo para el movimiento

		            AREA codigo,CODE
		            EXPORT inicio	    ; forma de enlazar con el startup.s
		            IMPORT srand	    ; para poder invocar SBR srand
		            IMPORT rand			; para poder invocar SBR rand
;MAIN
inicio	            ; se recomienda poner punto de parada (breakpoint) en la primera
		            ; instruccion de codigo para poder ejecutar todo el Startup de golpe

                    ;Habilitar interrupcion en VIC
                    ;RSI_timer
                    ldr r0, =VICVectAddr0
        	        ldr r1, =RSI_timer
        	        ldr r2, =IRQ_Index_timer
        	        str r1, [r0, r2, LSL#2]
        	        ldr r0, =VICIntEnable
        	        ldr r1, [r0]
        	        mov r1, #1<<IRQ_Index_timer
        	        str r1, [r0]
        	        ;RSI_teclado
		            ldr r0, =VICVectAddr0
		            ldr r1, =RSI_teclado
		            ldr r2, =IRQ_Index_tec
		            str r1,[r0,r2,LSL #2]	    ;VI[r2] = @RSI_teclado
                    ldr r0, =VICIntEnable       ;r0 = @VICIntEnable
                    ldr r1, [r0]
		            mov r1,#2_10000000		    ;r1 = #2_10000000
		            str r1,[r0]				    ;VICIntEnable [7] = 1(habilit. IRQ7)

                    ;Iniciar pantalla
ini_pantalla        LDR r0, =pantalla           ; r0=@pantalla
                    mov r2, #ancho
                    mov r3, #espacio
                    mov r4, #jugador
                    eor r1,r1,r1                ; i = 0
buc_col             cmp r1, #ancho              ; while( i < columnas)
                    beq fin_col
                    eor r5,r5,r5                ; j = 0
buc_fil             cmp r5, #alto               ; while( j < filas)
                    beq fin_fil
                    mla r6, r5, r2, r0          ; r6 = (j*columnas) + @pantalla
                    add r6, r6, r1              ; m[i][j] = r6 + i
                    strb r3,[r6]                ; m[i][j] = espacio
                    add r5,r5,#1                ; j++
                    b buc_fil
fin_fil             add r1,r1,#1                ; i++
                    b buc_col
fin_col             mov r1, #15                 ; i = 15
                    mov r5, #7                  ; j = 7
                    mla r6, r5, r2, r0          ; r6 = ( j * columnas ) + @pantalla
                    add r6, r6, r1              ; m[15][7] = r6 + i
fin_ini_pantalla    strb r4,[r6]                ; m[15][7] = jugador

                    ;iniciar posicion inicial en el medio de la matriz
                    LDR r0,=dir_posicion
                    str r6, [r0]               ; posicion = r6 = (7*columnas) + @pantalla + 15 = m[15][7]
                    LDR r7, =fila
                    mov r8 ,#7
                    str r8,[r7]
                    LDR r7, =columna 
                    mov r8 ,#15
                    str r8,[r7]

                    LDR r0,=semilla
                    PUSH {r0}
                    bl srand
                    sub sp,sp,#4

                    ;bucle programa
bucle               LDR r5, =fin                ; @fin
                    ldrb r6, [r5]               ; r6 = fin
                    cmp r6,#1                   ; if(fin==1)
                    beq fin_juego

                    ;bucle tiempo
iterar              LDR r7, =reloj
                    ldr r8, [r7]                ; r8 = reloj

                    LDR r0, =cont
                    ldr r1,[r0]
                    cmp r8, r1                  ;if( reloj == cont)
                    beq if_mov

                    LDR r2, =cont_simbolo
                    ldr r3,[r2]
                    cmp r8, r3                  ;if( reloj == cont_simbolo)
                    beq if_simbolo
                    b iterar

                    LDR r4, =reloj_fin
                    ldr r4,[r4]
                    ldr r5, =3000
                    cmp r4, r5 ; if(tiempo_fin = 3000)
                    beq perder
                    b iterar

perder              mov r6, #1
                    strb r6,[r7]                ; fin = 1
                    b bucle

if_simbolo          ;si toca añadir ‘$’
                    ;calcular instante siguiente aparición ‘$’
                    LDR r0, =cont_simbolo
                    ldr r1,[r0]                 ; r1 = cont_simbolo
                    add r1,r1,#512
                    str r1,[r0]
                    ;generar posicion aleatoria ‘$’
                    ;generar numero aletorio
                    bl rand
                    POP {r0}
	                LDR r2, =pantalla
	                bic r0,r0,#0xFFFFFF00
	                add r2,r2,r0
	                ;dibujar nuevo ‘$’
				    mov r1,#simbolo
	                strb r1, [r2]
                    ;dividir tiempo
                    LDR r0, =max
                    ldr r1, [r0]                ; r1 = max
                    mov r2, r1, LSR #1          ;max = max/2
                    str r2,[r0]
fin_if_simbolo      b bucle

if_mov              ; calcular instante siguiente movimiento
                    LDR r2, =cont
                    ldr r3,[r2]                 ; r1 = cont
                    add r3,r3,#8                ; r1 = cont + 8
                    str r3,[r2]
                    ;si toca mover ‘#’
                    LDR r0,=dirx
                    ldr r0,[r0]                ; r1 = dirx
                    LDR r1, =diry
                    ldr r1,[r1]                ; r3 = diry
                    cmp r0,#0                   ; if(dirx != 0 || diry != 0)
                    cmpeq r1,#0
                    beq fin_if_mov
                    ;borrar ‘#’ anterior
                    ;calcular nueva posicion ‘#’
                    ;dibujar nuevo ‘#’
                    cmp r0,#1                   ; if(dir x = 1)
                    beq mover_derecha
                    cmp r0,#-1                  ; if(dir x = -1)
                    beq mover_izquierda
                    cmp r1,#1                   ; if(dir y = 1)
                    beq mover_abajo
                    cmp r1,#-1                 ; if(dir y = -1)
                    beq mover_arriba
fin_if_mov          b bucle


                    ;Inhabilitar interrupciones en el VIC
                    ;RSI_timer
fin_juego           LDR r0, = VICIntEnClr	    ;r0 = @VICIntEnClr
                    mov r1,#2_10000	            ;r1 = #2_10000
                    str r1,[r0]			        ;VICIntEnClr[4] = 1 -> VICIntEnable[4] = 0
                    ;RSI_teclado
        	        LDR r0, = VICIntEnClr	    ;r0 = @VICIntEnClr
                    mov r1,#2_10000000		    ;r1 = #2_10000000
                    str r1,[r0]			        ;VICIntEnClr[7] = 1 -> VICIntEnable[7] = 0
                    ;Desprogramar VIC
                    LDR r0, =VICVectAddr0
                    mov r1, #IRQ_Index_timer
                    mov r2, #IRQ_Index_tec
                    eor r3,r3,r3                ;r3 = 0
                    str r3, [r0,r1,LSL#2]
                    str r3, [r0,r2,LSL#2]

bfin                b bfin
;FIN_MAIN


; MOVIMIENTOS
mover_derecha       LDR r7, =dir_posicion
                    ldr r0,[r7] ;
                    mov r1, #espacio
                    strb r1,[r0]                ; posicion = #espacio
                    ;comprobar si ha llegado al extremo
if_dcha             LDR r1, =columna
                    ldr r2,[r1]                 ; r2 = columna
                    cmp r2, #31                 ; if(columna == 31)
                    bne else_dcha
                    sub r2,r2,#31
                    str r2,[r1]                 ; columna = columna -31
                    sub r0,r0,#31               ; posicion = posicion - 31
                    ;comprobar si hay un simbolo en esa posicion
                    ldrb r2, [r0]               ; posicion2 = espacio || simbolo
                    cmp r2, #simbolo            ; if(posicion2 == simbolo)
                    bne guardar_dcha
                    ;if(posicion2 == simbolo) => dividir tiempo
                    LDR r3, =max
                    ldr r4, [r3]                 ; r4 = max
                    mov r4, r4, LSR #1           ; max = max/2
                    LDR r5, =reloj_fin
                    ldr r6 ,[r5]
                    eor r6,r6,r6                 ; r6 = 0
                    str r6,[r5]                  ; reloj_fin = 0
                    b guardar_dcha
else_dcha           ;else
                    add r0,r0,#1                 ; @posicion = @posicion +  1
                    LDR r1, =columna
                    ldr r2,[r1]                  ; r2 = columna
                    add r2,r2,#1                 ; columna ++
                    str r2,[r1]
                    ldrb r2, [r0]                ; posicion2 = espacio || simbolo
                    cmp r2, #simbolo             ; if(posicion2 == simbolo)
                    bne guardar_dcha
                    ;if(posicion2 == simbolo) == true => dividir tiempo
                    LDR r3, =max
                    ldr r4, [r3]                 ; r4 = max
                    mov r4, r4, LSR #1           ; max = max/2
                    str r4,[r3];
                    LDR r5, =reloj_fin
                    ldr r6 ,[r5]
                    eor r6,r6,r6                ; r6 = 0
                    str r6,[r5]                 ; reloj_fin = 0
guardar_dcha        mov r6, #jugador
                    strb r6,[r0]
                    str r0, [r7]
                    b fin_if_mov



mover_izquierda     LDR r7, =dir_posicion
                    ldr r0, [r7]
                    mov r1, #espacio
                    strb r1,[r0]
                    ;comprobar si ha llegado al extremo
if_izda             LDR r1, =columna
                    ldrb r2,[r1]
                    cmp r2, #0                   ; if(columna == 0)
                    bne else_izda
                    add r2,r2,#31                ; columna = columna + 31
                    str r2,[r1]
                    add r0,r0,#31                ; posicion = posicion + 31
                    ldrb r2, [r0]                 ; posicion2 = espacio || simbolo
                    cmp r2, #simbolo             ; if(posicion2 == simbolo)
                    bne guardar_izda
                    ;if(posicion2 == simbolo) == true => dividir tiempo
                    LDR r3, =max
                    ldr r4, [r3]
                    mov r4, r4, LSR #1           ; max = max/2
                    LDR r5, =reloj_fin
                    ldr r6 ,[r5]
                    eor r6,r6,r6
                    str r6,[r5]
                    b guardar_izda
else_izda           ;else
                    sub r0,r0,#1                 ; @posicion = @posicion -  1
                    LDR r1, =columna
                    ldr r2,[r1]                  ; r2 = columna
                    sub r2,r2,#1                 ; columna --
                    str r2,[r1]
                    ldrb r2, [r0]                ; posicion = espacio || simbolo
                    cmp r2, #simbolo             ; if(posicion2 == simbolo)
                    bne guardar_izda
                    ;if(posicion2 == simbolo) == true => dividir tiempo
                    LDR r3, =max
                    ldr r4, [r3]
                    mov r4, r4, LSR #1           ; max = max/2
                    str r4,[r3];
                    LDR r5, =reloj_fin
                    ldr r6 ,[r5]
                    eor r6,r6,r6
                    str r6,[r5]
guardar_izda        mov r6, #jugador
                    strb r6,[r0]
                    strb r0,[r7]
                    b fin_if_mov

mover_abajo         LDR r7, =dir_posicion
                    ldr r0,[r7]
                    mov r1, #espacio
                    strb r1,[r0]
                    ;comprobar si ha llegado al extremo
if_abajo            LDR r1, =fila
                    ldr r2,[r1]
                    cmp r2, #15                  ; if(fila == 15)
                    bne else_abajo
                    sub r2,r2,#15                ; fila = fila - 15
                    str r2,[r1]
                    sub r0,r0,#480               ; posicion = posicion - 480
                    ldrb r2, [r0]                ; posicion2 = espacio || simbolo
                    cmp r2, #simbolo             ; if(posicion2 == simbolo)
                    bne guardar_abajo
                    ;if(posicion2 == simbolo) == true => dividir tiempo
                    LDR r3, =max
                    ldr r4, [r3]
                    mov r4, r4, LSR #1           ; max = max/2
                    LDR r5, =reloj_fin
                    ldr r6 ,[r5]
                    eor r6,r6,r6
                    str r6,[r5]
                    b guardar_abajo
else_abajo           ;else
                    add r0,r0,#32                ; @posicion = @posicion +  1
                    LDR r1, =fila
                    ldr r2,[r1]
                    add r2,r2,#1
                    str r2,[r1]
                    ldrb r2, [r0]                 ; posicion = espacio || simbolo
                    cmp r2, #simbolo              ; if(posicion2 == simbolo)
                    bne guardar_abajo
                    ;if(posicion2 == simbolo) == true => dividir tiempo
                    LDR r3, =max
                    ldr r4, [r3]
                    mov r4, r4, LSR #1           ; max = max/2
                    str r4,[r3];
                    LDR r5, =reloj_fin
                    ldr r6 ,[r5]
                    eor r6,r6,r6
                    str r6,[r5]
guardar_abajo       mov r6, #jugador
                    strb r6,[r0]
                    str r0,[r7]
                    b fin_if_mov



mover_arriba        LDR r7, =dir_posicion
                    ldr r0,[r7]
                    mov r1, #espacio
                    strb r1,[r0]
                    ;comprobar si ha llegado al extremo
if_arriba           LDR r1, =fila
                    ldr r2,[r1]
                    cmp r2, #0                   ; if(fila == 0)
                    bne else_arriba
                    add r2,r2,#15                ; fila = fila + 15
                    str r2,[r1]
                    add r0,r0,#480               ; posicion = posicion + 480
                    ldrb r2, [r0]                 ; posicion2 = espacio || simbolo
                    cmp r2, #simbolo             ; if(posicion2 == simbolo)
                    bne guardar_arriba
                    ;if(posicion2 == simbolo) == true => dividir tiempo
                    LDR r3, =max
                    ldr r4, [r3]
                    mov r4, r4, LSR #1           ; max = max/2
                    LDR r5, =reloj_fin
                    ldr r6 ,[r5]
                    eor r6,r6,r6
                    str r6,[r5]
                    b guardar_arriba
else_arriba          ;else
                    sub r0,r0,#32                ; @posicion = @posicion +  1
                    LDR r1, =fila
                    ldr r2,[r1]
                    sub r2,r2,#1
                    str r2,[r1]
                    ldrb r2, [r0]                 ; posicion = espacio || simbolo
                    cmp r2, #simbolo             ; if(posicion2 == simbolo)
                    bne guardar_arriba
                    ;if(posicion2 == simbolo) == true => dividir tiempo
                    LDR r3, =max
                    ldr r4, [r3]
                    mov r4, r4, LSR #1           ; max = max/2
                    str r4,[r3];
                    LDR r5, =reloj_fin
                    ldr r6 ,[r5]
                    eor r6,r6,r6
                    str r6,[r5]
guardar_arriba      mov r6, #jugador
                    strb r6,[r0]
                    str  r0,[r7]
                    b fin_if_mov

;SUBRUTINAS TRATAMIENTO EXCEPCIONES
RSI_timer
                    ;guarda direccion de retorno, palabra de estado,
        	        sub lr, lr,#4	    ;actualiza el PC de retorno para que apunte a la @siguiente
        	        push {lr}
        	        mrs r14,spsr
        	        push {r14}	        ;se guarda la spsr en la pila (usando lr)
                    ;salva registros a usar
        	        push {r0,r1}
                    ;activa IRQ
        	        mrs r1,cpsr	         ;para habilitar IRQ de la palabra de estado del modo activo
        	        bic r1,r1,#I_Bit     ;pone a 0 el bit de las IRQ
        	        msr	cpsr_c,r1	     ;_c indica se copian el byte menos significativo
                    ;deactiva del VIC la peticion
        	        LDR r0,=T0_IR
        	        mov r1,#1
        	        str r1,[r0]

                    ;tratamiento interrupcion
        	        LDR r0,=reloj      ;carga la variable reloj
        	        ldr r1,[r0]
        	        add r1,r1,#1        ;aumenta la cuenta
        	        str r1,[r0]		    ;almacena el valor en reloj
        	        LDR r2, =reloj_fin  ;carga la variable reloj_fin
        	        ldr r3,[r2]
        	        add r3,r3,#1        ;aumenta la cuenta
        	        str r3, [r2]        ;almacena el valor en reloj_fin

                    ;desactiva IRQ
        	        mrs r1,cpsr
        	        orr r1,r1,#I_Bit
        	        msr cpsr_cxsf,r1
                    ;restaura registros
        	        pop {r0,r1}
                    ;desapila spsr y retorna al programa principal
           	        pop {r14}
        	        msr spsr_cxsf,r14  	      ;restaura el spsr dela pila
        	        LDR r14,=VICVectAddr
        	        str r14,[r14]
        	        pop {pc}^
fin_timer

RSI_teclado         ;guarda direccion de retorno, palabra de estado,
                    sub lr,lr,#4
		            PUSH {lr}
		            mrs r14,spsr
		            PUSH {r14}
		            ;activa IRQ
		            msr cpsr_c , #2_01010010   ; activar interrupcion IRQ
		            ;salva registros a usar
		            PUSH {r0-r4}
		            ;lee el codigo ASCII introducido
		            LDR r1,=TEC_DAT		       ;r1 = @r1_datos teclado
		            ldrb r0,[r1]			   ;r0 = cod ASCII tecla

                    ;tratamiento interrupcion
                    cmp r0,#arriba             ;if(r0 == I )
                    beq mov_arriba
                    cmp r0,#arriba_min         ;if(r0 == i )
                    beq mov_arriba

                    cmp r0,#izquierda          ;if(r0 == J )
                    beq mov_izq
                    cmp r0,#izquierda_min      ;if(r0 == j )
                    beq mov_izq

                    cmp r0,#abajo              ;if(r0 == K )
                    beq mov_abajo
                    cmp r0,#abajo_min          ;if(r0 == k )
                    beq mov_abajo

                    cmp r0,#derecha;           ;if(r0 == L )
                    beq mov_dcha
                    cmp r0,#derecha_min        ;if(r0 == l )
                    beq mov_dcha

                    cmp r0, #aumentar          ;if(r0 == + )
                    beq aumentar_velocidad

                    cmp r0, #disminuir         ;if(r0 == - )
                    beq disminuir_velocidad

                    cmp r0,#acabar             ;if(r0 == Q )
                    beq acabar_partida
                    cmp r0,#acabar_min         ;if(r0 == q )
                    beq acabar_partida


mov_arriba          LDR r0, =diry
                    mov r1,#-1
                    str r1, [r0]               ; diry = -1
                    b anular_dirx

mov_izq             LDR r0, =dirx
                    mov r1,#-1
                    str r1, [r0]               ; dirx = -1
                    b anular_diry

mov_abajo           LDR r0, =diry
                    mov r1, #1
                    str r1, [r0]               ; diry = 1
                    b anular_dirx

mov_dcha            LDR r0, =dirx
                    mov r1,#1
                    str r1, [r0]               ; dirx = 1
                    b anular_diry

anular_dirx         LDR r0, =dirx
                    mov r1,#0
                    str r1, [r0]               ; dirx = 0
                    b fin_tec

anular_diry         LDR r0, =diry
                    mov r1,#0
                    str r1, [r0]               ; diry = 0
                    b fin_tec

aumentar_velocidad  LDR r0, =max
                    ldr r1, [r0]                ; r1= max
                    mov r2,r1,LSL#1             ; r2 = max*2
                    LDR r3, =velocidad_maxima
                    ldr r4,[r3]                 ; r4 = velocidad_maxima
                    cmp r2,r4                   ; if ( max * 2 > velocidad_maxima)
                    strgt r4,[r0]               ;max = velocidad_maxima
                    str r2,[r0]                 ;max = max*2
                    b fin_tec

disminuir_velocidad LDR r0, =max
                    ldr r1, [r0]                ; r1= max
                    mov r2,r1,LSR#1             ; r2 = max/2
                    LDR r3, =velocidad_minima
                    ldr r4,[r3]                 ; r4 = velocidad_minima
                    cmp r2,r4                   ; if( max / 2 < velocidad_minima)
                    strlt r4,[r0]
                    str r2,[r0]
                    b fin_tec


acabar_partida      LDR r0, =fin
                    mov r1, #1
                    strb r1,[r0]                ; fin = 1

                    ;restaura registros
fin_tec             POP {r0-r4}
                    ;desactiva IRQ
            		msr cpsr_c,#2_11010010      ;I = 1 desactivar interrupcion IRQ
            		;desapila spsr y retorna al programa principal
            		POP {r14}				    ;r14 = cpsr prog. interrumpido
            		msr spsr_fsxc,r14		    ;spsr = cpsr prog. interrumpido
            		LDR r14,=VICVectAddr	    ;EOI r14 = @VICVectAddr
            		str r14,[r14]			    ;EOI escritura en VICVectAddr
            		POP {pc}^				    ;ret. a prog inter. + rec. estado
fin_RSI_teclado
                    END




