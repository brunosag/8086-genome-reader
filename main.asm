.model small
.stack
.data
	CR						equ	13
	LF						equ	10

	argv 					db	64	dup(0)
	token 					db	64	dup(0)

	input_file				db	64	dup(0)
	output_file				db	64	dup(0)
	group_size				db	0
	group_size_provided		db	0
	include_a				db	0
	include_t				db	0
	include_c				db	0
	include_g				db	0
	include_plus			db	0

.code
.startup
	call get_argv		; Obter argumentos da linha de comando
	
	call argv_token		; Obter primeiro token
	lea bx, token		; Imprimir token

.exit

;--------------------------------------------------------------------------------------------------
;	void argv_token()
;--------------------------------------------------------------------------------------------------    
argv_token				proc near
	lea si, argv		; Carregar string argv como entrada
	lea di, token		; Carregar buffer do token como saída
	mov dl, 32			; Definir SPACE como delimitador

load_char:
    mov al, [si]		; Obter caractere da entrada

    cmp al, dl			; Verificar delimitador
    je token_end
    cmp al, 0			; Verificar fim da string
    je token_end

    mov [di], al		; Copiar caractere para buffer do token
    inc si				; Mover para próximo caractere na entrada
    inc di				; Mover para próximo caractere no buffer do token
    jmp load_char

token_end:
    mov [di], 0			; Indicar fim do token no buffer

	inc si				; TODO: Remover token da string
	mov ax, si
	XCHG ax, argv

    cmp al, 0			; Verificar fim da string
	jne argv_token_ret

argv_end:
	mov argv, 0			; Indicar fim da string argv

argv_token_ret:
    ret

argv_token					endp

;--------------------------------------------------------------------------------------------------
;	void putchar(char c -> DL)
;--------------------------------------------------------------------------------------------------
putchar					proc near
	push ax				; Salvar registradores

	mov ah, 2
	int 21h

	pop ax				; Retornar registradores
	ret

putchar					endp

;--------------------------------------------------------------------------------------------------
;	void printf_s(char *s -> BX)
;--------------------------------------------------------------------------------------------------
printf_s				proc near
	push dx				; Salvar registradores

printf_s_loop:
	mov dl, [bx]		; while (*s != '\0')
	cmp dl, 0
	je printf_s_ret

	call putchar		; putchar(*s)

	inc bx				; s++;
	jmp printf_s_loop

printf_s_ret:
	pop dx				; Retornar registradores
	ret

printf_s				endp

;--------------------------------------------------------------------------------------------------
;	void get_argv()
;--------------------------------------------------------------------------------------------------
get_argv				proc near
	push ds				; Salvar registradores de segmentos
	push es

	mov ax, ds			; Trocar DS <-> ES para poder usar o MOVSB
	mov bx, es
	mov ds, bx
	mov es, ax

	mov si, 80h			; Obter o tamanho da string e colocar em CX
	mov ch, 0
	mov cl, [si]

	mov si, 81h			; Inicializar o ponteiro de origem
	lea di, argv		; Inicializar o ponteiro de destino

	rep movsb

	pop es				; Retornar registradores de segmentos
	pop ds

	ret

get_argv				endp

;--------------------------------------------------------------------------------------------------
;	void get_options()
;--------------------------------------------------------------------------------------------------
get_options				proc near

get_options				endp

;--------------------------------------------------------------------------------------------------
	end
;--------------------------------------------------------------------------------------------------
