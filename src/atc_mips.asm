# ==============================================================================
# ATC-MIPS: Controle de Trafego Aereo / Radar de Aproximacao de Pista
# ==============================================================================
# Disciplina: Arquitetura e Organizacao de Computadores (ICT-UNIFESP)
# Simulador:  MARS 4.5+ (Settings -> Memory Configuration -> Default)
# ==============================================================================

.data
.align 2
# Matriz da frota: 4 voos x 5 words (20 bytes/voo = 80 bytes em 0x10010000)
# Offsets: +0=ID, +4=ALT(1000..4000), +8=DIST(0..7), +12=FUEL, +16=STATE
# STATE:   0=APROX, 1=ORBITA, 2=AUTORIZADO, 3=POUSOU, 4=ACIDENTE
fleet_matrix:
    .word 101, 1000, 2,  5, 0       # Slot 1: VO-101 (1000 ft, 2 NM, 5 comb, APROX)
    .word 202, 2000, 4,  6, 0       # Slot 2: VO-202 (2000 ft, 4 NM, 6 comb, APROX)
    .word 303, 3000, 6,  9, 0       # Slot 3: VO-303 (3000 ft, 6 NM, 9 comb, APROX)
    .word 404, 4000, 6, 13, 1       # Slot 4: VO-404 (4000 ft, 6 NM, 13 comb, ORBITA)

# Tabelas de consulta (lookup tables) para nomes de estado e mensagens finais
state_names:        .word str_aprox, str_orbita, str_autorizado, str_pousou, str_acidente
end_messages:       .word str_end_victory, str_end_accident, str_end_exit, str_end_limit

# Variaveis globais da simulacao
turn_number:        .word 1         # Turno atual (1..20)
landed_count:       .word 0         # Quantidade de voos que pousaram (0..4)
runway_owner:       .word 0         # 0 = pista livre; 1..4 = slot autorizado
game_over:          .word 0         # 0=ativo, 1=vitoria, 2=acidente, 3=saida, 4=limite
input_buffer:       .space 64       # Buffer de texto para leitura segura (syscall 8)
state_symbols:      .byte ' ', '@', '*', ' ', 'X'  # Simbolo no radar para STATE 0, 1, 2 e 4(X)

# Textos da interface ASCII
str_intro:          .asciiz "\n=== ATC-MIPS :: CONTROLE DE APROXIMACAO DE PISTA ===\nObjetivo: Pousar os 4 voos na pista (00 NM) sem colisoes ou pane seca.\nRegras: Pouso exige Alt=1000 ft, Dist<=3 NM e Pista=0 (livre).\n        Cruzar 00 NM sem autorizacao ou zerar combustivel = ACIDENTE.\nRadar:  [k ] Aprox | [k@] Orbita | [k*] Autorizado | [==] Pista | [kX]/[XX] Acidente\n"
str_header_turn:    .asciiz "\n--- TURNO "
str_header_landed:  .asciiz "/20 | Pousos: "
str_header_runway:  .asciiz "/4 | Pista(0=livre): "
str_radar_border:   .asciiz "\n       +---------------------------------------+\n"
str_radar_axis:     .asciiz "       +---------------------------------------+\n          00   01   02   03   04   05   06   07 (NM)\nSlot | Voo    | Alt  | Dist | Comb | Estado\n-----+--------+------+------+------+-----------\n"
str_alt_label:      .asciiz "ft | "
str_cell_empty:     .asciiz "[  ] "
str_cell_runway:    .asciiz "[==] "
str_cell_collision: .asciiz "[XX] "
str_flight_prefix:  .asciiz "    | VO-"
str_sep:            .asciiz " | "
str_sep_dist:       .asciiz " | 0"
str_sep_fuel:       .asciiz "NM | "
str_sep_state:      .asciiz "   | "
str_pad_alt:        .asciiz "   "
str_aprox:          .asciiz "APROX\n"
str_orbita:         .asciiz "ORBITA\n"
str_autorizado:     .asciiz "AUTORIZADO\n"
str_pousou:         .asciiz "POUSOU\n"
str_acidente:       .asciiz "ACIDENTE\n"

str_prompt_main:    .asciiz "\nAcao: 1-4 (voo), 5 (avancar todos) ou 0 (sair): "
str_prompt_cmd:     .asciiz "Comando VO-"
str_prompt_opts:    .asciiz " [1-Descer | 2-Orbita | 3-Pouso | 4-Arremeter(Dist<=4) | 0-Voltar]: "
str_error_input:    .asciiz "Entrada invalida!\n"
str_error_inactive: .asciiz "Erro: voo inativo (ja pousou ou sofreu acidente).\n"
str_error_altitude: .asciiz "Negado: ja esta em 1000 ft.\n"
str_error_landing:  .asciiz "Pouso negado (requer Alt=1000, Dist<=3 e Pista livre).\n"
str_error_goaround: .asciiz "Arremetida negada (requer Dist<=4 NM).\n"

str_event_landed:   .asciiz "[POUSO] Voo pousou com seguranca! VO-"
str_event_limit:    .asciiz "[ACIDENTE] Limite 00 NM sem autorizacao! VO-"
str_event_fuel:     .asciiz "[ACIDENTE] Pane seca! VO-"
str_event_tcas:     .asciiz "[TCAS!] Proximidade perigosa na mesma altitude!\n"
str_event_collision:.asciiz "[ACIDENTE] Colisao aerea na mesma celula!\n"
str_newline:        .asciiz "\n"

str_end_victory:    .asciiz "\n=== VITORIA: Todos os 4 voos pousaram! ===\n"
str_end_accident:   .asciiz "\n=== FIM: Operacao encerrada por acidente! ===\n"
str_end_exit:       .asciiz "\n=== FIM: Encerrado pelo controlador. ===\n"
str_end_limit:      .asciiz "\n=== FIM: Limite de 20 turnos atingido. ===\n"

.text
.globl main

# ==============================================================================
# PROCEDIMENTO: main
# O que faz: Ponto de entrada. Mostra introducao, executa laco de turnos
#            (radar -> comando -> atualizacao) e imprime a mensagem final.
# ==============================================================================
main:
    li $v0, 4                       # syscall 4 = imprimir string (introducao)
    la $a0, str_intro
    syscall

main_turn_loop:
    lw $t0, game_over               # Encerra laco se game_over != 0
    bne $t0, $zero, main_finish
    jal print_radar_and_table       # Desenha cabecalho, radar 2D e tabela
    jal read_and_execute_command    # Le acao do usuario ($v0=0 se pediu sair)
    beq $v0, $zero, main_finish
    jal update_simulation_turn      # Atualiza voos, combustivel, pousos e colisoes
    j main_turn_loop

main_finish:
    lw $t0, game_over               # Carrega codigo de encerramento (1..4)
    beq $t0, 3, main_print_end      # Se saiu manualmente (3), nao repete radar
    jal print_radar_and_table       # Mostra estado final (vitoria/acidente/limite)
main_print_end:
    lw $t0, game_over               # Busca string final na tabela end_messages
    addi $t0, $t0, -1               # Converte codigo 1..4 em indice 0..3
    sll $t0, $t0, 2                 # Offset em bytes = indice * 4
    lw $a0, end_messages($t0)       # Carrega ponteiro da mensagem final
    li $v0, 4
    syscall
    li $v0, 10                      # syscall 10 = encerrar programa
    syscall

# ==============================================================================
# PROCEDIMENTO: get_aircraft_address
# O que faz: Calcula endereco do voo na matriz: fleet_matrix + idx * 20.
# Entrada:   $a0 = indice do voo (0..3) | Saida: $v0 = endereco base do voo
# ==============================================================================
get_aircraft_address:
    sll $t0, $a0, 4                 # $t0 = 16 * idx
    sll $t1, $a0, 2                 # $t1 = 4 * idx
    add $t0, $t0, $t1               # $t0 = 20 * idx (cada voo ocupa 5 words = 20 B)
    la $v0, fleet_matrix            # Endereco base da matriz (0x10010000)
    add $v0, $v0, $t0               # $v0 = endereco base do voo idx
    jr $ra                          # Retorna ao chamador

# ==============================================================================
# PROCEDIMENTO: read_validated_integer
# O que faz: Le texto via syscall 8 (sem syscall 5) para nao travar o MARS,
#            valida apenas digitos '0'..'9' e checa intervalo [$a0, $a1].
# Entrada:   $a0 = min, $a1 = max | Saida: $v0 = numero lido, $v1 = 1(ok)/0(erro)
# ==============================================================================
read_validated_integer:
    addi $sp, $sp, -8               # Preserva $s0 (min) e $s1 (max) na pilha
    sw $s0, 0($sp)
    sw $s1, 4($sp)
    move $s0, $a0                   # Salva limite minimo
    move $s1, $a1                   # Salva limite maximo

    li $v0, 8                       # syscall 8 = read_string (leitura segura)
    la $a0, input_buffer
    li $a1, 64
    syscall

    la $t0, input_buffer            # Cursor de leitura na string
    li $t2, 0                       # Acumulador do numero inteiro
    li $t3, 0                       # Contador de digitos lidos
read_int_char_loop:
    lb $t1, 0($t0)                  # Le 1 byte (caractere ASCII)
    beq $t1, $zero, read_int_validate  # Fim de string '\0'
    beq $t1, 10, read_int_validate     # Quebra de linha '\n'
    beq $t1, 32, read_int_skip_space   # Ignora espaco ' '
    blt $t1, 48, read_int_invalid      # Rejeita se < '0' (ASCII 48)
    bgt $t1, 57, read_int_invalid      # Rejeita se > '9' (ASCII 57)
    addi $t1, $t1, -48              # Converte ASCII para digito 0..9
    mul $t2, $t2, 10                # Desloca acumulador uma casa decimal
    add $t2, $t2, $t1               # Soma novo digito ao acumulador
    addi $t3, $t3, 1                # Incrementa contador de digitos
read_int_skip_space:
    addi $t0, $t0, 1                # Avanca para o proximo caractere
    j read_int_char_loop

read_int_validate:
    beq $t3, $zero, read_int_invalid # Rejeita linha vazia (0 digitos)
    blt $t2, $s0, read_int_invalid   # Rejeita se menor que o minimo
    bgt $t2, $s1, read_int_invalid   # Rejeita se maior que o maximo
    move $v0, $t2                   # Retorna numero valido em $v0
    li $v1, 1                       # $v1 = 1 (entrada valida)
    j read_int_return
read_int_invalid:
    li $v0, 0
    li $v1, 0                       # $v1 = 0 (entrada invalida)
read_int_return:
    lw $s0, 0($sp)                  # Restaura $s0, $s1 e libera pilha
    lw $s1, 4($sp)
    addi $sp, $sp, 8
    jr $ra

# ==============================================================================
# PROCEDIMENTO: print_radar_and_table
# O que faz: Imprime cabecalho (turno/pousos/pista), grade 2D ASCII (4000..1000 ft
#            x 00..07 NM) e tabela de status dos 4 voos.
# ==============================================================================
print_radar_and_table:
    addi $sp, $sp, -24              # Preserva $ra e $s0..$s4 na pilha
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)
    sw $s2, 12($sp)
    sw $s3, 16($sp)
    sw $s4, 20($sp)

    # 1) Cabecalho do turno (syscall 4 = string, syscall 1 = inteiro)
    li $v0, 4
    la $a0, str_header_turn
    syscall
    li $v0, 1
    lw $a0, turn_number             # Imprime numero do turno (1..20)
    syscall
    li $v0, 4
    la $a0, str_header_landed
    syscall
    li $v0, 1
    lw $a0, landed_count            # Imprime total de pousos (0..4)
    syscall
    li $v0, 4
    la $a0, str_header_runway
    syscall
    li $v0, 1
    lw $a0, runway_owner            # 0 = livre; 1..4 = slot reservando a pista
    syscall

    # 2) Grade 2D ASCII: $s0 = altitude (4000..1000), $s1 = distancia (0..7)
    li $v0, 4
    la $a0, str_radar_border
    syscall
    li $s0, 4000                    # Comeca do teto (4000 ft) ate 1000 ft
radar_altitude_loop:
    blt $s0, 1000, radar_print_table
    li $v0, 1                       # Imprime rotulo da linha ("4000ft | ")
    move $a0, $s0
    syscall
    li $v0, 4
    la $a0, str_alt_label
    syscall

    li $s1, 0                       # Percorre colunas de distancia 0..7 NM
radar_distance_loop:
    bgt $s1, 7, radar_next_altitude
    li $s2, 0                       # Quantidade de voos na celula ($s0, $s1)
    li $s3, -1                      # Indice do ultimo voo encontrado na celula
    li $s4, 0                       # Indice de varredura dos 4 voos (0..3)
radar_scan_aircraft:
    beq $s4, 4, radar_draw_cell
    move $a0, $s4
    jal get_aircraft_address        # $v0 = endereco base do voo $s4
    lw $t2, 16($v0)                 # Ignora apenas voos que ja pousaram (STATE == 3)
    beq $t2, 3, radar_scan_next
    lw $t2, 4($v0)                  # Compara ALT do voo com linha atual ($s0)
    bne $t2, $s0, radar_scan_next
    lw $t2, 8($v0)                  # Compara DIST do voo com coluna atual ($s1)
    bne $t2, $s1, radar_scan_next
    addi $s2, $s2, 1                # Encontrou voo nesta celula
    move $s3, $s4                   # Guarda qual voo esta na celula
radar_scan_next:
    addi $s4, $s4, 1
    j radar_scan_aircraft

radar_draw_cell:
    beq $s2, $zero, radar_draw_empty_or_runway  # 0 voos -> vazio ou pista
    bgt $s2, 1, radar_draw_collision            # 2+ voos -> colisao [XX]
    li $v0, 11                      # syscall 11 = char; imprime "[k<simbolo>] "
    li $a0, '['
    syscall
    li $v0, 1
    addi $a0, $s3, 1                # Imprime slot k (1..4)
    syscall
    move $a0, $s3
    jal get_aircraft_address
    lw $t2, 16($v0)                 # Carrega STATE para escolher simbolo
    lb $a0, state_symbols($t2)      # Busca ' ', '@', '*' ou 'X' na tabela
    li $v0, 11
    syscall
    li $a0, ']'
    syscall
    li $a0, ' '
    syscall
    j radar_next_distance

radar_draw_empty_or_runway:
    bne $s0, 1000, radar_draw_empty
    bne $s1, $zero, radar_draw_empty
    la $a0, str_cell_runway         # [==] na cabeceira da pista (1000ft, 00NM)
    j radar_print_cell
radar_draw_empty:
    la $a0, str_cell_empty          # Celula vazia "[  ] "
    j radar_print_cell
radar_draw_collision:
    la $a0, str_cell_collision      # [XX] quando 2+ voos ocupam a mesma celula
radar_print_cell:
    li $v0, 4
    syscall
radar_next_distance:
    addi $s1, $s1, 1                # Proxima coluna (+1 NM)
    j radar_distance_loop

radar_next_altitude:
    li $v0, 4
    la $a0, str_newline
    syscall
    addi $s0, $s0, -1000            # Proxima linha (-1000 ft)
    j radar_altitude_loop

    # 3) Rodape do radar e Tabela de Status dos 4 voos ($s0=idx, $s1=addr, $s2=STATE)
radar_print_table:
    li $v0, 4
    la $a0, str_radar_axis
    syscall

    li $s0, 0
radar_table_loop:
    beq $s0, 4, radar_return
    move $a0, $s0
    jal get_aircraft_address
    move $s1, $v0                   # Endereco base do voo
    lw $s2, 16($s1)                 # STATE (0..4)

    li $v0, 1                       # Coluna Slot (1..4)
    addi $a0, $s0, 1
    syscall
    li $v0, 4                       # "    | VO-"
    la $a0, str_flight_prefix
    syscall
    li $v0, 1                       # Coluna ID (101..404)
    lw $a0, 0($s1)
    syscall
    li $v0, 4
    la $a0, str_sep
    syscall
    lw $a0, 4($s1)                  # Coluna ALT (4 digitos ou 0 quando pousou)
    li $v0, 1
    syscall
    bne $a0, $zero, radar_print_dist # Se ALT == 0, completa coluna com 3 espacos
    li $v0, 4
    la $a0, str_pad_alt
    syscall
radar_print_dist:
    li $v0, 4                       # Coluna DIST formatada como "0XNM"
    la $a0, str_sep_dist
    syscall
    li $v0, 1
    lw $a0, 8($s1)
    syscall
    li $v0, 4
    la $a0, str_sep_fuel
    syscall
    lw $t0, 12($s1)                 # Coluna FUEL (2 digitos: se < 10, imprime '0')
    bge $t0, 10, radar_print_fuel
    li $v0, 11
    li $a0, '0'
    syscall
radar_print_fuel:
    li $v0, 1
    move $a0, $t0
    syscall
    li $v0, 4                       # Separador final antes do estado
    la $a0, str_sep_state
    syscall
    sll $t0, $s2, 2                 # Offset na lookup table (STATE * 4)
    lw $a0, state_names($t0)        # Imprime nome do estado ("APROX\n", etc.)
    syscall
    addi $s0, $s0, 1                # Proximo voo da tabela
    j radar_table_loop

radar_return:
    lw $ra, 0($sp)                  # Restaura registradores salvos e pilha
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    lw $s2, 12($sp)
    lw $s3, 16($sp)
    lw $s4, 20($sp)
    addi $sp, $sp, 24
    jr $ra

# ==============================================================================
# PROCEDIMENTO: read_and_execute_command
# O que faz: Le acao principal (1-4 voo, 5 avancar todos, 0 sair) e aplica o
#            comando no voo (1-Descer, 2-Orbita, 3-Pouso, 4-Arremeter).
# Saida:     $v0 = 1 (avancar turno) ou 0 (encerrar)
# ==============================================================================
read_and_execute_command:
    addi $sp, $sp, -12              # Preserva $ra, $s0 (slot) e $s1 (addr voo)
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)

command_ask_aircraft:
    li $v0, 4
    la $a0, str_prompt_main         # Pede 1-4 (voo), 5 (avancar) ou 0 (sair)
    syscall
    li $a0, 0                       # Limite minimo = 0
    li $a1, 5                       # Limite maximo = 5
    jal read_validated_integer
    bne $v1, $zero, command_check_slot
    la $a0, str_error_input         # Rejeita entrada invalida e repete
    j command_print_slot_error

command_check_slot:
    beq $v0, $zero, command_user_exit   # 0 = encerrar jogo
    beq $v0, 5, command_advance_turn    # 5 = avancar todos sem comando
    move $s0, $v0                   # $s0 = slot escolhido (1..4)
    addi $a0, $s0, -1               # Converte slot 1..4 para indice 0..3
    jal get_aircraft_address
    move $s1, $v0                   # $s1 = endereco base do voo na matriz
    lw $t0, 16($s1)                 # Le STATE do voo
    blt $t0, 3, command_ask_action  # Permite comando apenas se ativo (STATE < 3)
    la $a0, str_error_inactive
command_print_slot_error:
    li $v0, 4
    syscall
    j command_ask_aircraft

command_ask_action:
    li $v0, 4                       # Imprime "Comando VO-<ID> [opcoes]: "
    la $a0, str_prompt_cmd
    syscall
    li $v0, 1
    lw $a0, 0($s1)                  # ID do voo (101..404)
    syscall
    li $v0, 4
    la $a0, str_prompt_opts
    syscall
    li $a0, 0                       # Aceita comandos 0..4
    li $a1, 4
    jal read_validated_integer
    bne $v1, $zero, command_dispatch
    la $a0, str_error_input
    j command_print_action_error

command_dispatch:
    beq $v0, $zero, command_ask_aircraft  # 0 = voltar (nao gasta turno)
    beq $v0, 1, command_descend_altitude  # 1 = descer -1000 ft
    beq $v0, 2, command_toggle_orbit      # 2 = ligar/desligar orbita
    beq $v0, 3, command_authorize_landing # 3 = autorizar pouso
    j command_go_around                   # 4 = arremeter

command_descend_altitude:
    lw $t0, 4($s1)                  # Le ALT atual
    la $a0, str_error_altitude
    ble $t0, 1000, command_print_action_error  # Nao desce abaixo de 1000 ft
    addi $t0, $t0, -1000            # Desce 1000 ft
    sw $t0, 4($s1)
    lw $t1, 16($s1)
    bne $t1, 1, command_advance_turn # Se estava em ORBITA(1), volta para APROX(0)
    sw $zero, 16($s1)
    j command_advance_turn

command_toggle_orbit:
    lw $t0, 16($s1)                 # Se ja esta em ORBITA(1), sai dela
    beq $t0, 1, command_leave_orbit
    lw $t1, runway_owner            # Se tinha pista reservada, libera pista
    bne $t1, $s0, command_enter_orbit
    sw $zero, runway_owner
command_enter_orbit:
    li $t0, 1
    sw $t0, 16($s1)                 # STATE = ORBITA(1) (congela DIST)
    j command_advance_turn
command_leave_orbit:
    sw $zero, 16($s1)               # STATE = APROX(0) (retoma avanco)
    j command_advance_turn

command_authorize_landing:
    la $a0, str_error_landing
    lw $t0, 4($s1)                  # Regra 1: exige ALT == 1000 ft
    bne $t0, 1000, command_print_action_error
    lw $t0, 8($s1)                  # Regra 2: exige DIST <= 3 NM
    bgt $t0, 3, command_print_action_error
    lw $t0, runway_owner            # Regra 3: exige pista livre (0)
    bne $t0, $zero, command_print_action_error
    li $t0, 2
    sw $t0, 16($s1)                 # STATE = AUTORIZADO(2)
    sw $s0, runway_owner            # Reserva pista para este slot
    j command_advance_turn

command_go_around:
    la $a0, str_error_goaround
    lw $t0, 8($s1)                  # So permite arremeter perto da pista (DIST <= 4)
    bgt $t0, 4, command_print_action_error
    lw $t0, 4($s1)                  # Sobe +1000 ft (limitado ao teto 4000 ft)
    addi $t0, $t0, 1000
    ble $t0, 4000, command_save_go_around
    li $t0, 4000
command_save_go_around:
    sw $t0, 4($s1)                  # Salva nova altitude
    li $t0, 7                       # Grava 7 NM -> vira 6 NM apos -1 NM do turno
    sw $t0, 8($s1)
    lw $t1, runway_owner            # Libera pista se estava reservada por este voo
    bne $t1, $s0, command_reset_state
    sw $zero, runway_owner
command_reset_state:
    sw $zero, 16($s1)               # STATE = APROX(0)
    j command_advance_turn

command_print_action_error:
    li $v0, 4                       # Imprime motivo da recusa e repete pergunta
    syscall
    j command_ask_action

command_advance_turn:
    li $v0, 1                       # $v0 = 1 -> main avanca simulacao do turno
    j command_return
command_user_exit:
    li $t0, 3
    sw $t0, game_over               # game_over = 3 (encerrado pelo usuario)
    li $v0, 0                       # $v0 = 0 -> main encerra imediatamente
command_return:
    lw $ra, 0($sp)                  # Restaura registradores e pilha
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    addi $sp, $sp, 12
    jr $ra

# ==============================================================================
# PROCEDIMENTO: update_simulation_turn
# O que faz: Consome combustivel (-1), avanca voos (-1 NM fora de orbita),
#            checa pouso/acidente em 00 NM, pane seca, colisao/TCAS e fim de jogo.
# ==============================================================================
update_simulation_turn:
    addi $sp, $sp, -20              # Preserva $ra e $s0..$s3 na pilha
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)
    sw $s2, 12($sp)
    sw $s3, 16($sp)

    # Passo 1: Atualiza cada voo ($s0 = indice 0..3, $s1 = endereco do voo)
    li $s0, 0
turn_aircraft_loop:
    beq $s0, 4, turn_check_separation
    move $a0, $s0
    jal get_aircraft_address
    move $s1, $v0
    lw $t0, 16($s1)                 # Ignora voos inativos (POUSOU=3 ou ACIDENTE=4)
    bge $t0, 3, turn_next_aircraft

    lw $t1, 12($s1)                 # Consome 1 turno de combustivel
    addi $t1, $t1, -1
    sw $t1, 12($s1)

    beq $t0, 1, turn_check_fuel     # Em ORBITA(1) mantem distancia fixa
    lw $t2, 8($s1)                  # Avanca -1 NM em direcao a pista (00 NM)
    addi $t2, $t2, -1
    sw $t2, 8($s1)
    bgtz $t2, turn_check_fuel       # Se DIST > 0, ainda nao chegou na cabeceira

    # Chegou em 00 NM: exige STATE==2 (AUTORIZADO) e ALT==1000 ft para pousar
    bne $t0, 2, turn_crash_limit
    lw $t3, 4($s1)
    bne $t3, 1000, turn_crash_limit

    li $t1, 3                       # Pouso bem-sucedido! STATE = POUSOU(3)
    sw $t1, 16($s1)
    sw $zero, 4($s1)                # Zera ALT e libera pista
    sw $zero, runway_owner
    lw $t3, landed_count            # Incrementa contador de pousos
    addi $t3, $t3, 1
    sw $t3, landed_count
    la $a0, str_event_landed
    j turn_print_event

turn_crash_limit:
    li $t1, 4                       # Cruzou 00 NM sem autorizacao -> ACIDENTE(4)
    sw $t1, 16($s1)
    li $t1, 2
    sw $t1, game_over               # game_over = 2 (acidente)
    la $a0, str_event_limit
    j turn_print_event

turn_check_fuel:
    lw $t1, 12($s1)                 # Verifica se zerou o combustivel em voo
    bgtz $t1, turn_next_aircraft
    li $t1, 4                       # Pane seca -> STATE = ACIDENTE(4)
    sw $t1, 16($s1)
    li $t1, 2
    sw $t1, game_over               # game_over = 2 (acidente)
    la $a0, str_event_fuel

turn_print_event:
    li $v0, 4                       # Imprime mensagem do evento + ID + '\n'
    syscall
    li $v0, 1
    lw $a0, 0($s1)
    syscall
    li $v0, 4
    la $a0, str_newline
    syscall

turn_next_aircraft:
    addi $s0, $s0, 1                # Proximo voo da frota
    j turn_aircraft_loop

    # Passo 2: Compara pares ativos (0 <= i < j < 4) -> $s0=i, $s1=j, $s2=addr_i, $s3=addr_j
turn_check_separation:
    li $s0, 0
turn_pair_outer:
    bge $s0, 3, turn_check_end_game
    move $a0, $s0
    jal get_aircraft_address
    move $s2, $v0                   # Endereco do voo i
    lw $t0, 16($s2)                 # Pula se voo i ja pousou ou acidentou
    bge $t0, 3, turn_pair_next_i

    addi $s1, $s0, 1                # j comeca em i + 1 (evita testar par repetido)
turn_pair_inner:
    bge $s1, 4, turn_pair_next_i
    move $a0, $s1
    jal get_aircraft_address
    move $s3, $v0                   # Endereco do voo j
    lw $t0, 16($s3)                 # Pula se voo j esta inativo
    bge $t0, 3, turn_pair_next_j

    lw $t1, 4($s2)                  # Compara ALT_i e ALT_j (so conflita se iguais)
    lw $t2, 4($s3)
    bne $t1, $t2, turn_pair_next_j

    lw $t1, 8($s2)                  # Calcula distancia horizontal |DIST_i - DIST_j|
    lw $t2, 8($s3)
    sub $t3, $t1, $t2
    bgez $t3, turn_eval_distance    # Se positivo/zero, ja e o valor absoluto
    sub $t3, $zero, $t3             # Se negativo, inverte o sinal
turn_eval_distance:
    beq $t3, $zero, turn_air_collision  # Diferenca == 0 -> mesma celula (colisao)
    bne $t3, 1, turn_pair_next_j        # Diferenca >= 2 -> separacao segura
    li $v0, 4                           # Diferenca == 1 -> alerta TCAS!
    la $a0, str_event_tcas
    syscall
    j turn_pair_next_j

turn_air_collision:
    li $t0, 4                       # Marca ambos os voos como ACIDENTE(4)
    sw $t0, 16($s2)
    sw $t0, 16($s3)
    li $t0, 2
    sw $t0, game_over               # game_over = 2 (acidente)
    li $v0, 4
    la $a0, str_event_collision
    syscall
    j turn_pair_next_i              # Voo i ja acidentou; vai para o proximo i

turn_pair_next_j:
    addi $s1, $s1, 1
    j turn_pair_inner
turn_pair_next_i:
    addi $s0, $s0, 1
    j turn_pair_outer

    # Passo 3: Checa vitoria (4 pousos) ou limite de 20 turnos
turn_check_end_game:
    lw $t0, game_over               # Se ja houve acidente, nao sobrescreve
    bne $t0, $zero, turn_return
    lw $t0, landed_count
    bne $t0, 4, turn_increment_counter
    li $t1, 1                       # Todos os 4 pousaram -> game_over = 1 (vitoria)
    sw $t1, game_over
    j turn_return

turn_increment_counter:
    lw $t0, turn_number             # Se atingiu turno 20 sem finalizar -> limite(4)
    bge $t0, 20, turn_limit_reached
    addi $t0, $t0, 1                # Senao avanca para o proximo turno
    sw $t0, turn_number
    j turn_return
turn_limit_reached:
    li $t1, 4                       # game_over = 4 (limite de turnos)
    sw $t1, game_over

turn_return:
    lw $ra, 0($sp)                  # Restaura registradores e pilha
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    lw $s2, 12($sp)
    lw $s3, 16($sp)
    addi $sp, $sp, 20
    jr $ra
