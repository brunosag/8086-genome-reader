.model small
.stack

;======================================================================================================================
;	Macros
;======================================================================================================================

int_putchar		macro									; INT 21,2 - Display Output

				push	ax
				mov		ah, 2
				int		21h
				pop		ax
endm

int_terminate	macro	return_code 					; INT 21,4C - Terminate Process With Return Code

				mov		al, return_code
				mov		ah, 4Ch
				int		21h
endm

line_feed		macro									; Print LF character

				push	dx
				mov		dl, LF
				int_putchar
				pop		dx
endm

;======================================================================================================================
;	Constantes
;======================================================================================================================

; Geral
TRUE						equ		1
FALSE						equ		0
ERROR						equ		-1
STR_SIZE					equ		128

; Caracteres
NUL							equ		0
LF							equ		10
SPACE						equ		32

; Códigos de retorno
SUCCESS						equ		0
ERROR_INVALID_N				equ		1
ERROR_INVALID_OPTION		equ		2
ERROR_MISSING_F				equ		3
ERROR_MISSING_N				equ		4
ERROR_MISSING_ACTG			equ		5
ERROR_DUPLICATE_F			equ		6
ERROR_DUPLICATE_O			equ		7
ERROR_DUPLICATE_N			equ		8

;======================================================================================================================
;	Segmento de dados
;======================================================================================================================
.data

; Geral
return_code					db		SUCCESS
leading_zero				db		TRUE

; Processamento da linha de comando
argv 						db		STR_SIZE dup(0)
argv_cursor					dw		argv
token						dw		?

; Controle de parâmetros
input_file					db		STR_SIZE dup(0)
output_file					db		"a.out", (STR_SIZE - 5) dup(0)
group_size					dw		?
include_a					db		FALSE
include_t					db		FALSE
include_c					db		FALSE
include_g					db		FALSE
include_plus				db		FALSE
f_provided					db		FALSE
o_provided					db		FALSE
n_provided					db		FALSE

; Mensagens de erro
msg_invalid_n				db		"ERRO: parâmetro % é inválido para -n. Informe um número maior ou igual a 1.", NUL
msg_invalid_option			db		"ERRO: opção % é inválida.", NUL
msg_missing_f				db		"ERRO: opção -f não encontrada. Informe o arquivo de entrada.", NUL
msg_missing_n				db		"ERRO: opção -n não encontrada. Informe o tamanho dos grupos de bases.", NUL
msg_missing_atcg			db		"ERRO: opção -<atcg+> não encontrada. Informe as bases a serem processadas.", NUL
msg_duplicate_f				db		"ERRO: opção -f foi fornecida mais de uma vez. Informe apenas um arquivo de entrada.", NUL
msg_duplicate_o				db		"ERRO: opção -o foi fornecida mais de uma vez. Informe apenas um arquivo de saída.", NUL
msg_duplicate_n				db		"ERRO: opção -n foi fornecida mais de uma vez. Informe apenas um tamanho dos grupos de bases.", NUL

;======================================================================================================================
;	Segmento de código
;======================================================================================================================
.code
.startup
				call	get_argv					; Obter string da linha de comando
				call	join_segments				; Unir segmentos DS e ES
				call	get_options					; Extrair opções da linha de commando

				int_terminate	return_code			; Terminar programa com código de sucesso
.exit

;======================================================================================================================
;	void		argv_tok()
;======================================================================================================================
argv_tok		proc	near

				push	bx							; Salvar registradores
				mov		bx, argv_cursor				; Carregar cursor do argv em BX

check_space_start:
				mov		dl, [bx]					; Verificar SPACE no início da string
				cmp		dl, SPACE
				jne		check_nul_start
				inc		bx							; Pular caractere
				jmp		check_space_start

check_nul_start:
				cmp		dl, NUL						; Verificar NUL no início da string
				jne		get_token
				mov		token, NUL					; Salvar token nulo
				jmp		argv_tok_end

get_token:
				mov		token, bx					; Salvar endereço de início do token

check_space_end:
				mov		dl, [bx]					; Verificar SPACE
				cmp		dl, SPACE
				jne		check_nul_end
				mov 	byte ptr [bx], NUL			; Substituir SPACE por NUL para indicar fim do token
				inc		bx							; Pular caractere para próximo token
				jmp		argv_tok_end

check_nul_end:
				cmp		dl, NUL						; Vericiar NUL
				je		argv_tok_end

				inc		bx							; Próximo caractere
				jmp		check_space_end

argv_tok_end:
				mov		argv_cursor, bx				; Salvar posição atual do cursor
				pop		bx							; Retornar registradores
				ret

argv_tok		endp

;======================================================================================================================
;	int -> CX	divide_by_ten(int n -> CX)
;======================================================================================================================
divide_by_ten	proc	near

				push	ax							; Salvar registradores
				push	bx
				push	dx

				mov		ax, cx						; CX <- CX / 10
				mov		dx, 0
				mov		bx, 10
				div		bx
				mov		cx, ax

				pop		dx							; Retornar registradores
				pop		bx
				pop		ax

				ret

divide_by_ten	endp

;======================================================================================================================
;	void		printf_d(int n -> BX)
;======================================================================================================================
printf_d		proc	near

				mov		cx, 10000					; Inicializar contador
				mov		leading_zero, TRUE			; Ativar flag de zero à esquerda

printf_d_loop:
				cmp		cx, 1						; while (CX > 1)
				jng		printf_d_end

				mov		dx, 0						; DX <- 0
				mov		ax, bx						; AX <- n
				div		cx							; DX <- (DX:AX) % CX
				mov		ax, dx						; AX <- DX
				call	divide_by_ten				; CX <- CX / 10
				mov		dx, 0						; DX <- 0
				div		cx							; AX <- (DX:AX) / CX

				cmp		ax, 0						; Verificar se valor é 0
				jne		printf_d_put
				cmp		cx, 1						; Verificar se é o último dígito
				je		printf_d_put
				cmp		leading_zero, TRUE			; Verificar se é zero a esquerda
				je		printf_d_loop

printf_d_put:
				mov		leading_zero, FALSE			; Desativar flag de zero à esquerda
				mov		dl, al						; DL <- AL
				add		dl, '0'						; Converter dígito para caractere
				int_putchar							; Imprimir dígito
				jmp		printf_d_loop

printf_d_end:
				ret

printf_d		endp

;======================================================================================================================
;	void		printf_s(char *str -> BX, char *param -> AX)
;======================================================================================================================
printf_s		proc	near

				push	bx							; Salvar registradores

printf_s_loop:
				mov		dl, [bx]					; Obter caractere atual
				cmp		dl, NUL						; Verificar fim da string
				je		printf_s_end
				cmp		dl, '%'						; Verificar placeholder de parâmetro
				je		printf_s_param

				int_putchar							; Imprimir caractere

printf_s_next:
				inc		bx							; Próximo caractere
				jmp		printf_s_loop

printf_s_param:
				push	bx							; Imprimir string parâmetro
				mov		bx, ax
				call	printf_s
				pop		bx
				jmp		printf_s_next

printf_s_end:
				pop		bx							; Retornar registradores
				ret

printf_s		endp

;======================================================================================================================
;	void		get_argv()
;======================================================================================================================
get_argv		proc	near

				push	ds							; Salvar registradores de segmentos
				push	es

				mov		ax, ds						; Trocar DS <-> ES para uso do MOVSB
				mov		bx, es
				mov		ds, bx
				mov		es, ax

				mov		si, 80h						; Carregar tamanho da string
				mov		ch, 0
				mov		cl, [si]

				mov		si, 81h						; Carregar endereço de origem
				lea		di, argv					; Carregar endereço de destino

				rep 	movsb						; Mover string

				pop 	es							; Retornar registradores de segmentos
				pop 	ds

				ret

get_argv		endp

;======================================================================================================================
;	void		handle_error(int error_code -> DL, char *token -> AX)
;======================================================================================================================
handle_error	proc	near

				push	bx							; Salvar registradores

				cmp		dl, ERROR_INVALID_N			; Switch case para código de erro
				je		load_invalid_n
				cmp		dl, ERROR_INVALID_OPTION
				je		load_invalid_option
				cmp		dl, ERROR_MISSING_F
				je		load_missing_f
				cmp		dl, ERROR_MISSING_N
				je		load_missing_n
				cmp		dl, ERROR_MISSING_ACTG
				je		load_missing_atcg
				cmp		dl, ERROR_DUPLICATE_F
				je		load_duplicate_f
				cmp		dl, ERROR_DUPLICATE_O
				je		load_duplicate_o
				cmp		dl, ERROR_DUPLICATE_N
				je		load_duplicate_n

load_invalid_n:
				lea		bx, msg_invalid_n			; Carregar mensagem de "INVALID_N"
				jmp		print_msg

load_invalid_option:
				lea		bx, msg_invalid_option		; Carregar mensagem de "INVALID_OPTION"
				jmp		print_msg

load_missing_f:
				lea		bx, msg_missing_f			; Carregar mensagem de "MISSING_F"
				jmp		print_msg

load_missing_n:
				lea		bx, msg_missing_n			; Carregar mensagem de "MISSING_N"
				jmp		print_msg

load_missing_atcg:
				lea		bx, msg_missing_atcg		; Carregar mensagem de "MISSING_ACTG"
				jmp		print_msg

load_duplicate_f:
				lea		bx, msg_duplicate_f			; Carregar mensagem de "DUPLICATE_F"
				jmp		print_msg

load_duplicate_o:
				lea		bx, msg_duplicate_o			; Carregar mensagem de "DUPLICATE_O"
				jmp		print_msg

load_duplicate_n:
				lea		bx, msg_duplicate_n			; Carregar mensagem de "DUPLICATE_N"
				jmp		print_msg

print_msg:
				call	printf_s					; Imprimir mensagem
				line_feed
				mov		return_code, dl				; Atualizar código de retorno
				pop		bx							; Salvar registradores
				ret

handle_error	endp

;======================================================================================================================
;	int -> CX	strlen(char *str -> SI)
;======================================================================================================================
strlen			proc	near

				push	si							; Salvar registradores
				mov		cx, 0						; Zerar contador

count_char:
				cmp		byte ptr [si], NUL			; Verificar fim da string
				je		strlen_end
				inc		cx							; Incrementar contador
				inc		si							; Próximo caractere
				jmp		count_char

strlen_end:
				pop		si							; Retornar registradores
				ret

strlen			endp

;======================================================================================================================
;	int -> AX	atoi(char *str -> SI)
;======================================================================================================================
atoi			proc	near

				push	bx							; Salvar registradores
				mov		ax, 0						; Zerar acumulador
				mov		bl, 10						; Definir 10 como parâmetro para MUL

check_nul:
				cmp		byte ptr [si], NUL			; Verificar fim da string
				je		atoi_end

				cmp		byte ptr [si], '0'			; Verificar caractere não numérico
				jl		atoi_error
				cmp		byte ptr [si], '9'
				jg		atoi_error

				mul		bl							; AX <- AL * 10
				add		ax, [si]					; AX <- AX + caractere
				sub		ax, '0'						; AX <- AX - '0'

				inc		si							; Próximo caractere
				jmp		check_nul

atoi_error:
				mov		ax, ERROR

atoi_end:
				pop		bx							; Retornar registradores
				ret

atoi			endp

;======================================================================================================================
;	void		get_options()
;======================================================================================================================
get_options		proc	near

				call	argv_tok					; Obter primeiro token

check_token:
				mov		bx, token					; Carregar endereço do token em BX

				cmp		bx, NUL						; Verificar token nulo
				je		check_missing_f

check_option:
				cmp		byte ptr [bx], '-'			; Verificar início de opção ('-')
				jne		next_token
				inc		bx							; Pular caractere '-'

token_char:
				cmp		byte ptr [bx], NUL			; Verificar fim do token
				je		next_token

				cmp		byte ptr [bx], 'f'			; Switch case para caractere atual
				je		case_f
				cmp		byte ptr [bx], 'o'
				je		case_o
				cmp		byte ptr [bx], 'n'
				je		case_n
				cmp		byte ptr [bx], 'a'
				je		case_a
				cmp		byte ptr [bx], 't'
				je		case_t
				cmp		byte ptr [bx], 'c'
				je		case_c
				cmp		byte ptr [bx], 'g'
				je		case_g
				cmp		byte ptr [bx], '+'
				je		case_plus
				jmp		case_default

case_f:
				cmp		f_provided, TRUE			; Verificar opção -f duplicada
				je		handle_duplicate_f
				mov		f_provided, TRUE			; Ativar flag da opção -f
				call	argv_tok					; Obter parâmetro
				mov		si, token
				lea		di, input_file
				call	strlen						; Obter comprimento do parâmetro
				rep		movsb						; Mover parâmetro para input_file
				jmp		next_char

case_o:
				cmp		o_provided, TRUE			; Verificar opção -o duplicada
				je		handle_duplicate_o
				mov		o_provided, TRUE			; Ativar flag da opção -o
				call	argv_tok					; Obter parâmetro
				mov		si, token
				lea		di, output_file
				call	strlen						; Obter comprimento do parâmetro
				rep		movsb						; Mover parâmetro para output_file
				jmp		next_char

case_n:
				cmp		n_provided, TRUE			; Verificar opção -n duplicada
				je		handle_duplicate_n
				mov		n_provided, TRUE			; Ativar flag da opção -n
				call	argv_tok					; Obter parâmetro
				mov		si, token
				call	atoi						; Converter parâmetro para decimal
				cmp		ax, 1						; Verificar valor >= 1
				jge		valid_n
				mov		dl, ERROR_INVALID_N			; Tratar erro: parâmetro de -n inválido
				mov		ax, token
				call	handle_error
				jmp		next_char
valid_n:
				mov		group_size, ax				; Salvar valor do parâmetro em group_size
				jmp		next_char

case_a:
				mov		include_a, TRUE				; Ativar flag da opção -a
				jmp		next_char

case_t:
				mov		include_t, TRUE				; Ativar flag da opção -t
				jmp		next_char

case_c:
				mov		include_c, TRUE				; Ativar flag da opção -c
				jmp		next_char

case_g:
				mov		include_g, TRUE				; Ativar flag da opção -g
				jmp		next_char

case_plus:
				mov		include_plus, TRUE			; Ativar flag da opção -+
				jmp		next_char

case_default:
				mov		dl, ERROR_INVALID_OPTION	; Tratar erro: opção inválida
				mov		ax, token
				call	handle_error
				jmp		next_token

next_char:
				inc		bx							; Próximo caractere
				jmp		token_char

next_token:
				call	argv_tok					; Obter próximo token
				jmp		check_token

check_missing_f:
				cmp		f_provided, FALSE			; Verificar opção -f faltante
				je		handle_missing_f

check_missing_n:
				cmp		n_provided, FALSE			; Verificar opção -n faltante
				je		handle_missing_n

check_missing_atcg:
				cmp		include_a, TRUE				; Verificar opção -<atcg+> faltante
				je		get_options_end
				cmp		include_t, TRUE
				je		get_options_end
				cmp		include_c, TRUE
				je		get_options_end
				cmp		include_g, TRUE
				je		get_options_end
				cmp		include_plus, TRUE
				je		get_options_end
				jmp		handle_missing_atcg

handle_missing_f:
				mov		dl, ERROR_MISSING_F			; Tratar erro: opção -f faltante
				call	handle_error
				jmp		check_missing_n

handle_missing_n:
				mov		dl, ERROR_MISSING_N			; Tratar erro: opção -n faltante
				call	handle_error
				jmp		check_missing_atcg

handle_missing_atcg:
				mov		dl, ERROR_MISSING_ACTG		; Tratar erro: opção -<atcg+> faltante
				call	handle_error
				jmp		get_options_end

handle_duplicate_f:
				mov		dl, ERROR_DUPLICATE_F		; Tratar erro: opção -f duplicada
				call	handle_error
				jmp		next_char

handle_duplicate_o:
				mov		dl, ERROR_DUPLICATE_O		; Tratar erro: opção -o duplicada
				call	handle_error
				jmp		next_char

handle_duplicate_n:
				mov		dl, ERROR_DUPLICATE_N		; Tratar erro: opção -n duplicada
				call	handle_error
				jmp		next_char

get_options_end:
				cmp		return_code, SUCCESS		; Verificar se houve erros
				je		get_options_ret

				int_terminate	return_code			; Terminar programa com código de erro correspondente

get_options_ret:
				ret

get_options		endp

;======================================================================================================================
;	void		join_segments()
;======================================================================================================================
join_segments	proc	near

				mov		ax, ds
				mov		es, ax

				ret

join_segments	endp

;======================================================================================================================
				end
;======================================================================================================================
