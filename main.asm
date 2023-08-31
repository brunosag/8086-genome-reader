.model small
.stack

;==================================================================================================
;	Constantes e variáveis globais
;==================================================================================================
.data

; Constantes
	NUL							equ	0
	LF							equ	10
	CR							equ	13
	SPACE						equ	32
	STR_SIZE					equ	64

; Processamento da linha de comando
	argv 						db	STR_SIZE	dup(0)
	argv_cursor					dw	argv
	token						dw	?

; Controle de parâmetros
	input_file					db	STR_SIZE	dup(0)
	output_file					db	STR_SIZE	dup(0)
	group_size					db	?
	group_size_provided			db	0
	include_a					db	0
	include_t					db	0
	include_c					db	0
	include_g					db	0
	include_plus				db	0

;==================================================================================================
;	Segmento de código
;==================================================================================================
.code
.startup
				call	get_argv			; Obter string da linha de comando

				mov		bx, argv_cursor		; Imprimir string da linha de comando
				call	printf_s

				call	argv_tok			; Imprimir primeiro token
				mov		bx, token
				call	printf_s
.exit

;==================================================================================================
;	void argv_tok()
;==================================================================================================
argv_tok		proc	near

				mov		bx, argv_cursor		; Carregar cursor do argv em BX

check_space_start:
				mov		dl, [bx]			; Verificar SPACE no início da string
				cmp		dl, SPACE
				jne		check_nul_start
				inc		bx					; Pular caractere
				jmp		check_space_start

check_nul_start:
				cmp		dl, NUL				; Verificar NUL no início da string
				jne		get_token
				mov		token, bx			; Salvar token nulo
				jmp		argv_tok_end

get_token:
				mov		token, bx			; Salvar endereço de início do token

check_space_end:
				mov		dl, [bx]			; Verificar SPACE
				cmp		dl, SPACE
				jne		check_nul_end
				mov 	byte ptr [bx], NUL	; Substituir SPACE por NUL para indicar fim do token
				inc		bx					; Pular caractere para próximo token
				jmp		argv_tok_end

check_nul_end:
				cmp		dl, NUL				; Vericiar NUL
				je		argv_tok_end

				inc		bx					; Próximo caractere
				jmp		check_space_end

argv_tok_end:
				mov		argv_cursor, bx		; Salvar posição atual do cursor
				ret

argv_tok		endp

;==================================================================================================
;	void putchar(char c -> DL)
;==================================================================================================
putchar			proc	near

				push 	ax					; Salvar registradores

				mov 	ah, 2				; DOS Interrupt: Saída de caractere
				int 	21h

				pop 	ax					; Retornar registradores
				ret

putchar			endp

;==================================================================================================
;	void printf_s(char *s -> BX)
;==================================================================================================
printf_s		proc	near

				push	dx					; Salvar registradores

printf_s_loop:
				mov		dl, [bx]			; Verificar fim da string
				cmp		dl, 0
				je		printf_s_end

				call	putchar				; Imprimir caractere

				inc		bx					; Próximo caractere
				jmp		printf_s_loop

printf_s_end:
				pop		dx					; Retornar registradores
				ret

printf_s		endp

;==================================================================================================
;	void get_argv()
;==================================================================================================
get_argv		proc	near

				push	ds					; Salvar registradores de segmentos
				push	es

				mov		ax, ds				; Trocar DS <-> ES para uso do MOVSB
				mov		bx, es
				mov		ds, bx
				mov		es, ax

				mov		si, 80h				; Carregar tamanho da string
				mov		ch, 0
				mov		cl, [si]

				mov		si, 81h				; Carregar endereço de origem
				lea		di, argv			; Carregar endereço de destino

				rep 	movsb				; Mover string

				pop 	es					; Retornar registradores de segmentos
				pop 	ds

				ret

get_argv		endp

;==================================================================================================
;	void get_options()
;==================================================================================================
get_options		proc	near

get_options		endp

;==================================================================================================
	end
;==================================================================================================
