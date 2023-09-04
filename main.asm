;======================================================================================================================
;   8086_genome_reader
;======================================================================================================================
;
;   Autor:			Bruno Samuel A. Gonçalves
;   Data:			08/2023
;   Descrição:		Um leitor de sequências de DNA em linguagem de montagem para a arquitetura Intel 8086.
;
;   Utilização:
;		./main -f <input_file> -o <output_file> -n <base_group_size> -<actg+>
;
;======================================================================================================================

.model small
.stack

;======================================================================================================================
;	Macros
;======================================================================================================================

int_terminate	macro	return_code 					; INT 21,4C - Terminate Process With Return Code

				mov		al, return_code
				mov		ah, 4Ch
				int		21h
endm

line_feed		macro									; Print LF character

				push	dx
				mov		dl, LF
				call	putchar
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
BUFFER_SIZE					equ		20000

; Caracteres
NUL							equ		0
LF							equ		10
CR							equ		13
SPACE						equ		32

; Modos de accesso
READ_ONLY					equ		0
WRITE_ONLY					equ		1
READ_WRITE					equ		2

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
ERROR_FILE_NOT_EXIST		equ		9
ERROR_INVALID_BASE			equ		10
ERROR_NOT_ENOUGH_BASES		equ		11
ERROR_TOO_MANY_BASES		equ		12

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

; Leitura do arquivo
file_handle					dw		?
file_buffer					db		BUFFER_SIZE dup(0)
base_count					dw		0
group_count					dw		0
line_count					dw		1
base_line_count				dw		0
a_count						dw		0
t_count						dw		0
c_count						dw		0
g_count						dw		0
new_line					db		FALSE
nul_terminated_char			db		2 dup(0)

; Mensagens de erro
msg_invalid_n				db		"ERRO: parâmetro '%s' é inválido para -n. Informe um número maior ou igual a 1.", NUL
msg_invalid_option			db		"ERRO: opção '%s' é inválida.", NUL
msg_missing_f				db		"ERRO: opção -f não encontrada. Informe o arquivo de entrada.", NUL
msg_missing_n				db		"ERRO: opção -n não encontrada. Informe o tamanho dos grupos de bases.", NUL
msg_missing_atcg			db		"ERRO: opção -<atcg+> não encontrada. Informe as bases a serem processadas.", NUL
msg_duplicate_f				db		"ERRO: opção -f foi fornecida mais de uma vez. Informe apenas um arquivo de entrada.", NUL
msg_duplicate_o				db		"ERRO: opção -o foi fornecida mais de uma vez. Informe apenas um arquivo de saída.", NUL
msg_duplicate_n				db		"ERRO: opção -n foi fornecida mais de uma vez. Informe apenas um tamanho dos grupos de bases.", NUL
msg_file_not_exist			db		"ERRO: arquivo '%s' não existe.", NUL
msg_invalid_base			db		"ERRO: base '%s' na linha %d é inválida. Apenas 'A', 'T', 'C' e 'G' são aceitas.", NUL
msg_not_enough_bases		db		"ERRO: número de bases insuficiente. Forneça pelo menos %d bases no arquivo de entrada.", NUL
msg_too_many_bases			db		"ERRO: arquivo muito grande. São aceitas no máximo 10.000 bases nitrogenadas.", NUL

;======================================================================================================================
;	Segmento de código
;======================================================================================================================

.code
.startup
				call	get_argv					; Obter string da linha de comando
				call	join_segments				; Unir segmentos DS e ES
				call	get_options					; Extrair opções da linha de commando
				call	validate_input_file			; Validar arquivo de entrada

				int_terminate	return_code			; Terminar programa com código de sucesso

.exit

;----------------------------------------------------------------------------------------------------------------------
;	getargv
;----------------------------------------------------------------------------------------------------------------------
;	Função para obter a string de argumentos da linha de comando e armazenar na variável 'argv'.
;----------------------------------------------------------------------------------------------------------------------
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

;----------------------------------------------------------------------------------------------------------------------
;	get_options
;----------------------------------------------------------------------------------------------------------------------
;	Função para extrair as opções de uma string de argumentos e as armazenar nas variáveis correspondentes.
;----------------------------------------------------------------------------------------------------------------------
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

				int_terminate	return_code			; Terminar programa com código de erro

get_options_ret:
				ret

get_options				endp

;----------------------------------------------------------------------------------------------------------------------
;	validate_input_file
;----------------------------------------------------------------------------------------------------------------------
;	Função para ler e validar a existência, tamanho e conteúdo do arquivo de entrada.
;----------------------------------------------------------------------------------------------------------------------
validate_input_file		proc	near

				mov		al, READ_ONLY				; Definir leitura como modo de acesso
				lea		dx, input_file				; Carregar endereço do nome do arquivo
				call	fopen						; Abrir arquivo
				mov		file_handle, ax				; Salvar handle do arquivo

validate_input_file_loop:
				cmp		base_count, 10000			; Verificar máximo de bases
				jge		handle_too_many_bases

				mov		bx, file_handle				; Carregar handle do arquivo
				lea		dx, file_buffer				; Carregar endereço do buffer
				mov		cx, 1						; Definir leitura de 1 byte

				call	fread						; Ler caractere
				cmp		ax, 0						; Verificar fim do arquivo
				je		check_min_bases

				mov		bx, dx
				cmp		byte ptr [bx], 'A'			; Verificar caractere válido
				je		count_base
				cmp		byte ptr [bx], 'T'
				je		count_base
				cmp		byte ptr [bx], 'C'
				je		count_base
				cmp		byte ptr [bx], 'G'
				je		count_base
				cmp		byte ptr [bx], LF			; Verificar quebra de linha
				je		count_line
				cmp		byte ptr [bx], CR
				je		validate_input_file_loop
				jmp		handle_invalid_base

count_base:
				inc		base_count					; Contar base
				mov		new_line, FALSE				; Desativar flag de nova linha
				jmp		validate_input_file_loop

count_line:
				inc		line_count					; Contar linha
				cmp		new_line, TRUE				; Verificar se há bases na linha
				je		validate_input_file_loop
				inc		base_line_count				; Contar linha com base
				mov		new_line, TRUE				; Ativar flag de nova linha
				jmp		validate_input_file_loop

handle_invalid_base:
				mov		dl,	ERROR_INVALID_BASE		; Tratar erro: base inválida
				mov		al, [bx]
				lea		si, nul_terminated_char
				mov		[si], al
				lea		ax, nul_terminated_char
				mov		bx,	line_count
				call	handle_error
				jmp		validate_input_file_end

handle_too_many_bases:
				mov		dl, ERROR_TOO_MANY_BASES
				call	handle_error
				jmp		validate_input_file_end

check_min_bases:
				mov		bx, group_size				; Verificar mínimo de bases
				cmp		base_count, bx
				jnl		validate_input_file_end
				mov		dl, ERROR_NOT_ENOUGH_BASES
				call	handle_error

validate_input_file_end:
				mov		ax, base_count				; Calcular número de grupos
				sub		ax, group_size
				inc		ax
				mov		group_count, ax

				mov		bx, file_handle				; Fechar arquivo
				call	fclose
				cmp		return_code, SUCCESS		; Verificar se houve erros
				je		validate_input_file_ret
				int_terminate	return_code			; Terminar programa com código de erro

validate_input_file_ret:
				ret

validate_input_file		endp

;----------------------------------------------------------------------------------------------------------------------
;	argv_tok
;----------------------------------------------------------------------------------------------------------------------
;	Função para realizar a segmentação de uma string de argumentos em tokens individuais, efetuando
;	o tratamento de espaços e delimitadores.
;----------------------------------------------------------------------------------------------------------------------
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

;----------------------------------------------------------------------------------------------------------------------
;	handle_error
;----------------------------------------------------------------------------------------------------------------------
;	Função para lidar com erros com base em seus códigos, exibindo uma mensagem correspondente e atualizando
;	o código de retorno.
;
;	Entrada:
;		- DL (int):		código de erro
;		- AX (char *):	endereço da string a ser inserida como parâmetro na mensagem de erro
;		- BX (int):		número inteiro a ser inserido como parâmetro na mensagem de erro
;----------------------------------------------------------------------------------------------------------------------
handle_error	proc	near

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
				cmp		dl, ERROR_FILE_NOT_EXIST
				je		load_file_not_exist
				cmp		dl, ERROR_INVALID_BASE
				je		load_invalid_base
				cmp		dl, ERROR_TOO_MANY_BASES
				je		load_too_many_bases
				cmp		dl, ERROR_NOT_ENOUGH_BASES
				je		load_not_enough_bases

load_invalid_n:
				lea		si, msg_invalid_n			; Carregar mensagem de "INVALID_N"
				jmp		print_msg

load_invalid_option:
				lea		si, msg_invalid_option		; Carregar mensagem de "INVALID_OPTION"
				jmp		print_msg

load_missing_f:
				lea		si, msg_missing_f			; Carregar mensagem de "MISSING_F"
				jmp		print_msg

load_missing_n:
				lea		si, msg_missing_n			; Carregar mensagem de "MISSING_N"
				jmp		print_msg

load_missing_atcg:
				lea		si, msg_missing_atcg		; Carregar mensagem de "MISSING_ACTG"
				jmp		print_msg

load_duplicate_f:
				lea		si, msg_duplicate_f			; Carregar mensagem de "DUPLICATE_F"
				jmp		print_msg

load_duplicate_o:
				lea		si, msg_duplicate_o			; Carregar mensagem de "DUPLICATE_O"
				jmp		print_msg

load_duplicate_n:
				lea		si, msg_duplicate_n			; Carregar mensagem de "DUPLICATE_N"
				jmp		print_msg

load_file_not_exist:
				lea		si, msg_file_not_exist		; Carregar mensagem de "FILE_NOT_EXIST"
				jmp		print_msg

load_invalid_base:
				lea		si, msg_invalid_base		; Carregar mensagem de "INVALID_BASE"
				mov		dx,	bx
				jmp		print_msg

load_too_many_bases:
				lea		si, msg_too_many_bases		; Carregar mensagem de "TOO_MANY_BASES"
				jmp		print_msg

load_not_enough_bases:
				lea		si, msg_not_enough_bases	; Carregar mensagem de "NOT_ENOUGH_BASES"
				mov		dx,	bx
				jmp		print_msg

print_msg:
				call	printf						; Imprimir mensagem
				line_feed
				mov		return_code, dl				; Atualizar código de retorno
				ret

handle_error	endp

;----------------------------------------------------------------------------------------------------------------------
;	fopen
;----------------------------------------------------------------------------------------------------------------------
;	Função para abrir um arquivo no modo especificado e retornar um handle.
;
;	Entrada:
;		- AL (int):		modo de acesso
;		- DX (char *):	endereço do nome do arquivo
;
;	Saída:
;		- AX (char *):	handle do arquivo aberto
;----------------------------------------------------------------------------------------------------------------------
fopen			proc	near

				mov		ah, 3Dh						; INT 21,3D - Open File Using Handle
				int		21h

				jnc		fopen_end					; Verificar existência do arquivo

				mov		dl, ERROR_FILE_NOT_EXIST	; Tratar erro: arquivo não existe
				lea		ax, input_file
				call	handle_error
				int_terminate	return_code			; Terminar programa com código de erro

fopen_end:
				ret

fopen			endp

;----------------------------------------------------------------------------------------------------------------------
;	fclose
;----------------------------------------------------------------------------------------------------------------------
;	Função para fechar um arquivo a partir de um handle
;
;	Entrada:
;		- BX (char *):	handle do arquivo a ser fechado
;----------------------------------------------------------------------------------------------------------------------
fclose			proc	near

				mov		ah, 3Eh						; INT 21,3E - Close File Using Handle
				int		21h

				ret

fclose			endp

;----------------------------------------------------------------------------------------------------------------------
;	fread
;----------------------------------------------------------------------------------------------------------------------
;	Função para ler um arquivo e armazenar seu conteúdo em um buffer.
;
;	Entrada:
;		- BX (char *):	handle do arquivo
;		- DX (char *):	endereço do buffer
;		- CX (int):		número de bytes a serem lidos
;
;	Saída:
;		- AX (int):		número de bytes lidos
;----------------------------------------------------------------------------------------------------------------------
fread			proc	near

				mov		ah, 3Fh						; INT 21,3F - Read From File or Device Using Handle
				int		21h

				ret

fread			endp

;----------------------------------------------------------------------------------------------------------------------
;	printf
;----------------------------------------------------------------------------------------------------------------------
;	Função para imprimir uma string, permitindo a inclusão opcional de uma string, indicada
;	por "%s", e de um inteiro, indicada por "%d".
;
;	Entrada:
;		- SI (char *):	endereço da string a ser impressa
;		- AX (char *):	endereço da string a ser inserida como parâmetro
;		- DX (int):		número inteiro a ser inserido como parâmetro
;----------------------------------------------------------------------------------------------------------------------
printf			proc	near

				mov		bx, dx						; Salvar decimal e liberar DX

printf_loop:
				cmp		byte ptr [si], NUL			; Verificar fim da string
				je		printf_end
				cmp		byte ptr [si], '%'			; Verificar placeholder de parâmetro
				je		printf_param

				mov		dl, byte ptr [si]			; Imprimir caractere
				call	putchar

printf_next:
				inc		si							; Próximo caractere
				jmp		printf_loop

printf_param:
				inc		si							; Verificar parâmetro string ou decimal
				cmp		byte ptr [si], 's'
				je		printf_str
				cmp		byte ptr [si], 'd'
				je		printf_int

				dec		si							; Imprimir '%' normalmente
				call	putchar
				jmp		printf_loop

printf_str:
				push	si							; Imprimir string parâmetro
				mov		si, ax
				call	printf_s
				pop		si
				jmp		printf_next

printf_int:
				call	printf_d					; Imprimir decimal parâmetro
				jmp		printf_next

printf_end:
				ret

printf			endp

;----------------------------------------------------------------------------------------------------------------------
;	printf_s
;----------------------------------------------------------------------------------------------------------------------
;	Função para imprimir uma string terminada em '\0'.
;
;	Entrada:
;		- SI (char *):	endereço da string a ser impressa
;----------------------------------------------------------------------------------------------------------------------
printf_s		proc	near

printf_s_loop:
				cmp		byte ptr [si], NUL			; Verificar fim da string
				je		printf_s_end

				mov		dl, byte ptr [si]			; Imprimir caractere
				call	putchar

printf_s_next:
				inc		si							; Próximo caractere
				jmp		printf_s_loop

printf_s_end:
				ret

printf_s		endp

;----------------------------------------------------------------------------------------------------------------------
;	printf_d
;----------------------------------------------------------------------------------------------------------------------
;	Função para imprimir um número inteiro.
;
;	Entrada:
;		- BX (int):		número a ser impresso
;----------------------------------------------------------------------------------------------------------------------
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
				call	putchar						; Imprimir dígito
				jmp		printf_d_loop

printf_d_end:
				ret

printf_d		endp

;----------------------------------------------------------------------------------------------------------------------
;	putchar
;----------------------------------------------------------------------------------------------------------------------
;	Função para imprimir um caractere.
;
;	Entrada:
;		- DL (char):	caractere a ser impresso
;----------------------------------------------------------------------------------------------------------------------
putchar			proc	near

				push	ax								; Salvar registradores

				mov		ah, 2							; INT 21,2 - Display Output
				int		21h

				pop		ax								; Retornar registradores
				ret

putchar			endp

;----------------------------------------------------------------------------------------------------------------------
;	strlen
;----------------------------------------------------------------------------------------------------------------------
;	Função para calcular o comprimento de uma string terminada em '\0'.
;
;	Entrada:
;		- SI (char *):	endereço da string
;
;	Saída:
;		- CX (int):		comprimento da string
;----------------------------------------------------------------------------------------------------------------------
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

;----------------------------------------------------------------------------------------------------------------------
;	atoi
;----------------------------------------------------------------------------------------------------------------------
;	Função para converter uma string de caracteres numéricos em um número inteiro.
;
;	Entrada:
;		- SI (char *):	endereço da string
;
;	Saída:
;		- AX (int):		número inteiro
;----------------------------------------------------------------------------------------------------------------------
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

;----------------------------------------------------------------------------------------------------------------------
;	divide_by_ten
;----------------------------------------------------------------------------------------------------------------------
;	Função para dividir um número por 10.
;
;	Entrada:
;		- CX (int):		número a ser dividido
;
;	Saída:
;		- CX (int):		número dividido por 10
;----------------------------------------------------------------------------------------------------------------------
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

;----------------------------------------------------------------------------------------------------------------------
;	join_segments
;----------------------------------------------------------------------------------------------------------------------
;	Função para unir segmentos DS e ES.
;----------------------------------------------------------------------------------------------------------------------
join_segments	proc	near

				mov		ax, ds
				mov		es, ax

				ret

join_segments	endp

;----------------------------------------------------------------------------------------------------------------------
	end
;----------------------------------------------------------------------------------------------------------------------
