# ==============================================================================
# ATC-MIPS: Controle de Trafego Aereo / Radar de Aproximacao de Pista
# ==============================================================================
# Disciplina: Arquitetura e Organizacao de Computadores (ICT-UNIFESP)
# Simulador alvo: MARS 4.5+ (Console ASCII / Run I/O + Audio MIDI syscall 31)
# ==============================================================================

.data
.align 2
# ------------------------------------------------------------------------------
# Matriz da frota: 6 aeronaves x 6 words (24 bytes por aeronave = 144 bytes)
# Offsets por aeronave:
#   +0  : ID    (101, 202, 303, 404, 505, 606)
#   +4  : ALT   (1000, 2000, 3000, 4000 ft; 0 se pousou)
#   +8  : DIST  (0..10 NM ate a cabeceira da pista)
#   +12 : FUEL  (combustivel restante em turnos)
#   +16 : STATE (0=AGUARDANDO, 1=APROXIMACAO, 2=ORBITA, 3=AUTORIZADO,
#                4=POUSOU, 5=MAYDAY, 6=ACIDENTE)
#   +20 : ALERT (0=OK, 1=MAYDAY, 2=TCAS!, 3=ARREM!)
# ------------------------------------------------------------------------------
fleet_matrix:       .space 144

# Cenario 1: Operacao Padrao (Trafego Moderado)
scenario_1_data:
    .word 101, 1000,  2,  6, 1, 0   # Slot 1: VO-101 (1000ft, 2NM, 6F, APROX)
    .word 202, 2000,  4,  5, 1, 0   # Slot 2: VO-202 (2000ft, 4NM, 5F, APROX)
    .word 303, 3000,  6,  9, 1, 0   # Slot 3: VO-303 (3000ft, 6NM, 9F, APROX)
    .word 404, 4000,  7, 18, 2, 0   # Slot 4: VO-404 (4000ft, 7NM, 18F, ORBITA)
    .word 505, 3000,  9, 13, 0, 0   # Slot 5: VO-505 (entra apos Turno 2)
    .word 606, 2000,  8, 15, 0, 0   # Slot 6: VO-606 (entra apos Turno 4)

# Cenario 2: Hora do Rush (5 voos ativos no Turno 1 + conflitos de altitude)
scenario_2_data:
    .word 101, 1000,  2,  7, 1, 0   # Slot 1: VO-101 (1000ft, 2NM, 7F, APROX)
    .word 202, 2000,  4,  7, 1, 0   # Slot 2: VO-202 (2000ft, 4NM, 7F, APROX)
    .word 303, 2000,  6, 10, 1, 0   # Slot 3: VO-303 (2000ft, 6NM, 10F, APROX)
    .word 404, 3000,  8, 15, 1, 0   # Slot 4: VO-404 (3000ft, 8NM, 15F, APROX)
    .word 505, 3000, 10, 17, 1, 0   # Slot 5: VO-505 (3000ft, 10NM, 17F, APROX)
    .word 606, 1000, 10, 18, 0, 0   # Slot 6: VO-606 (entra apos Turno 4)

# Cenario 3: Emergencia de Combustivel (Prioridade MAYDAY imediata)
scenario_3_data:
    .word 101, 1000,  2,  3, 5, 1   # Slot 1: VO-101 (1000ft, 2NM, 3F, MAYDAY)
    .word 202, 2000,  3,  3, 5, 1   # Slot 2: VO-202 (2000ft, 3NM, 3F, MAYDAY)
    .word 303, 2000,  5,  6, 1, 0   # Slot 3: VO-303 (2000ft, 5NM, 6F, APROX)
    .word 404, 3000,  8, 11, 1, 0   # Slot 4: VO-404 (3000ft, 8NM, 11F, APROX)
    .word 505, 3000,  9, 13, 0, 0   # Slot 5: VO-505 (entra apos Turno 2)
    .word 606, 3000, 10, 15, 0, 0   # Slot 6: VO-606 (entra apos Turno 4)

# Variaveis globais de estado da simulacao
active_scenario:    .word 1         # 1=Padrao, 2=Rush, 3=Emergencia
turn_number:        .word 1
landed_count:       .word 0
incidents_count:    .word 0
tcas_warnings:      .word 0
runway_reserved_by: .word 0         # 0 = livre, 1..6 = slot autorizado
game_over_flag:     .word 0         # 0=ativo, 1=vitoria, 2=acidente, 3=saida, 4=limite
total_commands:     .word 0
current_score:      .word 0

# Buffer de leitura segura via syscall 8 (read_string)
input_buffer:       .space 64

# ------------------------------------------------------------------------------
# Mensagens iniciais, briefing e manual completo
# ------------------------------------------------------------------------------
str_briefing:
    .asciiz "\n========================================================================\n  ATC-MIPS :: CONTROLADOR DE APROXIMACAO DE PISTA (TERMINAL ASCII)\n========================================================================\nOBJETIVO:\n  Gerencie o pouso seguro de 6 aeronaves em uma unica pista (00 NM),\n  evitando colisoes aereas (mesma altitude e distancia) e pane seca.\n\nCOMO FUNCIONA CADA TURNO:\n  - Voos em APROXIMACAO ou MAYDAY avancam -1 NM por turno; em ORBITA\n    mantem a distancia constante, mas TODOS em voo consomem 1 Comb/turno.\n  - Pouso valido exige: Altitude = 1000 ft, Dist <= 3 NM e Pista LIVRE.\n  - Pares na mesma altitude com |DistA - DistB| <= 1 geram alerta TCAS!.\n  - No painel principal, escolha uma aeronave (1-6), avance o turno (7)\n    mantendo todos no curso, ou consulte o Manual Completo (8) sem custo.\n========================================================================\n"

str_manual:
    .asciiz "\n==================== MANUAL COMPLETO DE OPERACAO ======================\n1. LEITURA DO RADAR 2D (Altitude x Distancia ate a Pista 00 NM):\n   [==] Cabeceira da pista (1000 ft, 00 NM)\n   [k ] Voo k em aproximacao normal     [k*] Voo k autorizado para pouso\n   [k@] Voo k em espera/orbita          [k!] Voo k em MAYDAY/TCAS!/ARREM!\n   [XX] Duas ou mais aeronaves na mesma celula (risco/colisao)\n\n2. TELEMETRIA E ESTADOS:\n   AGUARDANDO  : Entrara no setor em onda futura (Turno 2 ou Turno 4).\n   APROXIMACAO : Avanca -1 NM/turno e consome 1 Comb/turno.\n   ORBITA      : Mantem distancia fixa, mas consome 1 Comb/turno.\n   AUTORIZADO  : Pista reservada; pousa ao cruzar 00 NM a 1000 ft.\n   MAYDAY      : Combustivel critico (<= 3 turnos restantes).\n\n3. COMANDOS DA TORRE E DA AERONAVE:\n   Painel (1-6): abre comandos para o voo (descer -1000 ft, subir +1000 ft,\n   alternar orbita, autorizar pouso, arremeter +1000 ft/+3 NM, manter curso).\n   Painel (7)  : Avanca 1 turno mantendo todas as aeronaves no perfil atual.\n   Painel (8)  : Exibe este manual a qualquer momento sem consumir o turno.\n\n4. PONTUACAO E RANKING DO CONTROLADOR:\n   +100 pts + (10 x Comb restante) por pouso seguro\n   -15 pts por arremetida manual | -40 pts por arremetida automatica\n   -25 pts por alerta TCAS!       | -300 pts por acidente (colisao/pane)\n   Ranks (sem acidentes): S (>=750) | A (>=650) | B (>=500) | C (<500)\n========================================================================\n"

str_scen_menu:
    .asciiz "\n--- SELECAO DE CENARIO DE OPERACAO ---\n  1 - Operacao Padrao (Trafego Moderado)\n  2 - Hora do Rush (5 Voos Ativos + Conflitos de Altitude)\n  3 - Emergencia de Combustivel (Prioridade MAYDAY)\n  4 - Ver Manual Completo, Regras e Pontuacao\n  0 - Encerrar Simulador\nEscolha uma opcao (0-4): "

str_scen_1_name:    .asciiz "Operacao Padrao"
str_scen_2_name:    .asciiz "Hora do Rush   "
str_scen_3_name:    .asciiz "Emerg. MAYDAY  "
str_early_quit:     .asciiz "\nSimulador encerrado antes do inicio da operacao.\n"

# ------------------------------------------------------------------------------
# Secao [1] Caixa de Radio / Eventos do Turno
# ------------------------------------------------------------------------------
str_box_radio_hdr:
    .asciiz "\n[1] CAIXA DE RADIO / EVENTOS DO TURNO\n------------------------------------------------------------------------\n"
str_box_radio_start:
    .asciiz "  >> Torre: Operacao iniciada! Radar sincronizado e pista liberada.\n"
str_box_radio_all:
    .asciiz "  >> Torre: Todas as aeronaves mantem o perfil atual neste turno.\n"
str_box_radio_none:
    .asciiz "  (Nenhum evento critico adicional registrado na passagem do turno.)\n"
str_box_radio_ftr:
    .asciiz "------------------------------------------------------------------------\n"

# ------------------------------------------------------------------------------
# Secao [2] Cabecalho do Setor
# ------------------------------------------------------------------------------
str_sec2_hdr:
    .asciiz "\n[2] CABECALHO DO SETOR :: TURNO "
str_turn_of:        .asciiz " / 25 | Cenario: "
str_score_lbl:      .asciiz " | Score: "
str_pts_lbl:        .asciiz " pts\n"
str_status_bar1:    .asciiz "    Pista: "
str_pista_livre:    .asciiz "LIVRE         "
str_pista_res1:     .asciiz "RESERV(VO-"
str_pista_res2:     .asciiz ")"
str_status_bar2:    .asciiz " | Pousos: "
str_status_bar3:    .asciiz "/6 | Alertas TCAS: "
str_status_bar4:    .asciiz " | Acidentes: "

# ------------------------------------------------------------------------------
# Secao [3] Radar 2D ASCII e Legenda
# ------------------------------------------------------------------------------
str_sec3_hdr:       .asciiz "\n[3] RADAR DE APROXIMACAO 2D (ALTITUDE x DISTANCIA)\n"
str_alt_4000:       .asciiz "4000ft | "
str_alt_3000:       .asciiz "3000ft | "
str_alt_2000:       .asciiz "2000ft | "
str_alt_1000:       .asciiz "1000ft | "
str_radar_border:   .asciiz "       +------------------------------------------------------+\n"
str_radar_axis:     .asciiz "          00   01   02   03   04   05   06   07   08   09   10  (NM)\n"
str_radar_legend:   .asciiz "Legenda: [k ] Aprox | [k*] Autoriz | [k@] Orbita | [k!] Alerta | [XX] Colisao | [==] Pista\n"

str_cell_empty:     .asciiz "[  ] "
str_cell_runway:    .asciiz "[==] "
str_cell_multi:     .asciiz "[XX] "
str_cell_lbrack:    .asciiz "["
str_cell_rbrack:    .asciiz "] "

# ------------------------------------------------------------------------------
# Secao [4] Tabela de Telemetria da Frota
# ------------------------------------------------------------------------------
str_sec4_hdr:
    .asciiz "\n[4] TABELA DE TELEMETRIA DA FROTA\nSlot | Voo    | Alt(ft) | Dist(NM) | Comb | Estado       | Alerta\n-----+--------+---------+----------+------+--------------+--------\n"
str_voo_prefix:     .asciiz " | VO-"
str_pipe_sp:        .asciiz " | "
str_na_alt:         .asciiz "   ----"
str_na_dist:        .asciiz "    ----"
str_sp1:            .asciiz " "
str_sp2:            .asciiz "  "
str_sp3:            .asciiz "   "
str_sp6:            .asciiz "      "
str_sp7:            .asciiz "       "
str_newline:        .asciiz "\n"

# Strings de estado (todas com 12 caracteres para alinhamento da tabela)
str_st_wait:        .asciiz "AGUARDANDO  "
str_st_app:         .asciiz "APROXIMACAO "
str_st_orb:         .asciiz "ORBITA      "
str_st_clr:         .asciiz "AUTORIZADO  "
str_st_lnd:         .asciiz "POUSOU      "
str_st_may:         .asciiz "MAYDAY      "
str_st_acc:         .asciiz "ACIDENTE    "

# Strings de alerta
str_al_ok:          .asciiz "OK"
str_al_mayday:      .asciiz "MAYDAY!"
str_al_tcas:        .asciiz "TCAS!"
str_al_arrem:       .asciiz "ARREM!"

# ------------------------------------------------------------------------------
# Secao [5] Painel de Comando da Torre e Submenu da Aeronave
# ------------------------------------------------------------------------------
str_sec5_panel:
    .asciiz "\n[5] PAINEL DE COMANDO DA TORRE\n  1..6 : Emitir ordem para uma aeronave ativa\n  7    : Avancar turno (manter todas as aeronaves no curso atual)\n  8    : Consultar Manual Completo / Regras\n  0    : Encerrar operacao\nEscolha uma opcao (0-8): "

str_err_input:      .asciiz "Entrada invalida! Digite apenas um numero inteiro dentro da faixa.\n"
str_err_wait:       .asciiz "Erro: Esta aeronave ainda aguarda entrada no setor.\n"
str_err_landed:     .asciiz "Erro: Esta aeronave ja concluiu o pouso.\n"
str_err_accident:   .asciiz "Erro: Esta aeronave sofreu acidente e esta inoperante.\n"

str_sel_summary1:   .asciiz "\n--- Ordem para VO-"
str_sel_summary2:   .asciiz " (Alt="
str_sel_summary3:   .asciiz "ft, Dist="
str_sel_summary4:   .asciiz "NM, Comb="
str_sel_summary5:   .asciiz ") ---\n"
str_menu_opts:
    .asciiz "  1 - Reduzir altitude (-1000 ft)\n  2 - Subir altitude (+1000 ft)\n  3 - Alternar espera em orbita\n  4 - Autorizar pouso (Alt=1000, Dist<=3, Pista livre)\n  5 - Arremeter (+1000 ft, +3 NM) [-15 pts]\n  6 - Manter curso desta aeronave (avancar turno)\n  0 - Voltar ao painel principal\nDigite o comando (0-6): "

str_err_min_alt:    .asciiz "Comando rejeitado: aeronave ja esta na altitude minima (1000 ft).\n"
str_err_max_alt:    .asciiz "Comando rejeitado: aeronave ja esta no teto do setor (4000 ft).\n"
str_err_lnd_alt:    .asciiz "Pouso negado: altitude deve ser 1000 ft.\n"
str_err_lnd_dist:   .asciiz "Pouso negado: distancia maxima para autorizacao e 3 NM.\n"
str_err_lnd_dup:    .asciiz "Aviso: esta aeronave ja esta autorizada para pouso.\n"
str_err_lnd_busy:   .asciiz "Pouso negado: pista ja reservada por outra aeronave.\n"

str_ok_desc:        .asciiz "  >> Ordem confirmada: VO-"
str_ok_desc2:       .asciiz " desceu para "
str_ok_climb2:      .asciiz " subiu para "
str_ft_nl:          .asciiz " ft.\n"
str_ok_orb_in:      .asciiz "  >> Ordem confirmada: VO-"
str_ok_orb_in2:     .asciiz " entrou em espera (orbita).\n"
str_ok_orb_out2:    .asciiz " retomou aproximacao.\n"
str_ok_clr2:        .asciiz " autorizado para POUSO e pista reservada!\n"
str_ok_go_cmd2:     .asciiz " executou ARREMETIDA manual. (-15 pts)\n"
str_ok_keep2:       .asciiz " mantem o perfil atual neste turno.\n"

# ------------------------------------------------------------------------------
# Mensagens de eventos do turno (impressas dentro da Caixa de Radio)
# ------------------------------------------------------------------------------
str_evt_land1:      .asciiz "  [POUSO] VO-"
str_evt_land2:      .asciiz " pousou com seguranca! Pista liberada. (+"
str_evt_pts_end:    .asciiz " pts)\n"
str_evt_auto_ga1:   .asciiz "  [ARREMETIDA AUTO] VO-"
str_evt_auto_ga2:   .asciiz " cruzou 00 NM sem autorizacao! Reposicionado (3 NM, >=2000 ft). (-40 pts)\n"
str_evt_mayday1:    .asciiz "  [ALERTA MAYDAY] VO-"
str_evt_mayday2:    .asciiz " com combustivel critico!\n"
str_evt_fuel1:      .asciiz "  [ACIDENTE - PANE SECA] VO-"
str_evt_fuel2:      .asciiz " esgotou o combustivel! (-300 pts)\n"
str_evt_tcas1:      .asciiz "  [ALERTA TCAS!] Separacao minima violada entre VO-"
str_evt_tcas2:      .asciiz " e VO-"
str_evt_tcas3:      .asciiz "! (-25 pts)\n"
str_evt_col1:       .asciiz "  [ACIDENTE - COLISAO] Colisao aerea entre VO-"
str_evt_col3:       .asciiz "! (-300 pts)\n"
str_evt_wave1:      .asciiz "  [RADAR] Nova aeronave entrou no setor: VO-"
str_evt_wave2:      .asciiz "\n"

# ------------------------------------------------------------------------------
# Mensagens do Relatorio Final e Avaliacao de Desempenho
# ------------------------------------------------------------------------------
str_fin_hdr:        .asciiz "\n====================== RELATORIO FINAL ======================\n"
str_fin_win:        .asciiz "MISSAO CONCLUIDA: Todas as 6 aeronaves pousaram com seguranca!\n"
str_fin_acc:        .asciiz "EMERGENCIA CRITICA: Operacao encerrada apos acidente aereo.\n"
str_fin_exit:       .asciiz "OPERACAO ENCERRADA: Expediente finalizado pelo controlador.\n"
str_fin_lim:        .asciiz "LIMITE DE TURNOS ATINGIDO: Encerramento do expediente no setor.\n"
str_fin_stat0:      .asciiz "Cenario executado : "
str_fin_stat1:      .asciiz "\nTurnos executados : "
str_fin_stat2:      .asciiz "\nComandos emitidos : "
str_fin_stat3:      .asciiz "\nPousos concluidos : "
str_fin_stat4:      .asciiz "\nAlertas TCAS      : "
str_fin_stat5:      .asciiz "\nAcidentes         : "
str_fin_stat6:      .asciiz "\nPontuacao final   : "
str_fin_rank_lbl:   .asciiz " pts\nAvaliacao (Rank)  : "
str_rank_s:         .asciiz "RANK S - Controlador Chefe Exemplar"
str_rank_a:         .asciiz "RANK A - Controlador Senior"
str_rank_b:         .asciiz "RANK B - Controlador Pleno"
str_rank_c:         .asciiz "RANK C - Controlador Junior (com ressalvas)"
str_rank_inc:       .asciiz "INCOMPLETO - Operacao nao concluida"
str_rank_fail:      .asciiz "REPROVADO - Ocorrencia de acidente critico"
str_fin_ftr:        .asciiz "\n=============================================================\n"

.text
.globl main

# ==============================================================================
# PROCEDIMENTO: main
# Descricao: Exibe briefing inicial, seleciona o cenario e executa o laco por
#            turnos ate vitoria, acidente, limite ou encerramento pelo usuario.
# ==============================================================================
main:
    jal print_welcome_briefing
    jal select_scenario
    beq $v0, $zero, main_early_exit

    # Mensagem inicial na secao [1] Caixa de Radio
    li $v0, 4
    la $a0, str_box_radio_hdr
    syscall
    li $v0, 4
    la $a0, str_box_radio_start
    syscall
    li $v0, 4
    la $a0, str_box_radio_ftr
    syscall

main_loop:
    lw $t0, game_over_flag
    bne $t0, $zero, main_end

    # Secoes [2] Cabecalho, [3] Radar 2D ASCII e [4] Tabela de Telemetria
    jal render_ascii_radar

    # Secao [5] Painel de Comando e abertura da secao [1] do proximo ciclo
    jal process_controller_cmd
    beq $v0, $zero, main_end        # 0 = usuario optou por encerrar

    # Avanca simulacao e fecha a secao [1] Caixa de Radio
    jal update_simulation_turn
    j main_loop

main_end:
    lw $t0, game_over_flag
    li $t1, 3
    beq $t0, $t1, main_skip_final_radar
    jal render_ascii_radar
main_skip_final_radar:
    jal print_final_report
    li $v0, 10
    syscall

main_early_exit:
    li $v0, 4
    la $a0, str_early_quit
    syscall
    li $v0, 10
    syscall

# ==============================================================================
# PROCEDIMENTO: print_welcome_briefing
# Descricao: Exibe resumo inicial explicando objetivo, regras e interface.
# ==============================================================================
print_welcome_briefing:
    li $v0, 4
    la $a0, str_briefing
    syscall
    jr $ra

# ==============================================================================
# PROCEDIMENTO: print_help_manual
# Descricao: Exibe manual completo de leitura do radar, comandos e pontuacao.
# ==============================================================================
print_help_manual:
    li $v0, 4
    la $a0, str_manual
    syscall
    jr $ra

# ==============================================================================
# PROCEDIMENTO: select_scenario
# Descricao: Menu inicial de escolha de cenario deterministico (1..3), consulta
#            ao manual (4) ou saida (0).
# Saidas:   $v0 = cenario escolhido (1..3) ou 0 para sair
# ==============================================================================
select_scenario:
    addi $sp, $sp, -8
    sw $ra, 0($sp)
    sw $s0, 4($sp)

ss_prompt:
    li $v0, 4
    la $a0, str_scen_menu
    syscall

    li $a0, 0
    li $a1, 4
    jal read_safe_int
    bne $v1, $zero, ss_valid_opt

    li $v0, 4
    la $a0, str_err_input
    syscall
    li $a0, 1
    jal play_sound
    j ss_prompt

ss_valid_opt:
    beq $v0, $zero, ss_quit
    li $t0, 4
    beq $v0, $t0, ss_show_help

    move $s0, $v0                   # cenario 1..3
    move $a0, $s0
    jal init_fleet
    li $a0, 0
    jal play_sound
    move $v0, $s0
    j ss_exit

ss_show_help:
    jal print_help_manual
    j ss_prompt

ss_quit:
    li $v0, 0

ss_exit:
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    addi $sp, $sp, 8
    jr $ra

# ==============================================================================
# PROCEDIMENTO: init_fleet
# Descricao: Carrega os dados iniciais do cenario escolhido (1..3) para
#            fleet_matrix e reinicializa contadores e pontuacao.
# Entradas: $a0 = numero do cenario (1..3)
# ==============================================================================
init_fleet:
    sw $a0, active_scenario
    li $t0, 1
    beq $a0, $t0, if_scen1
    li $t0, 2
    beq $a0, $t0, if_scen2
    la $t0, scenario_3_data
    j if_copy_start
if_scen1:
    la $t0, scenario_1_data
    j if_copy_start
if_scen2:
    la $t0, scenario_2_data

if_copy_start:
    la $t1, fleet_matrix
    li $t2, 36                      # 6 aeronaves * 6 words

if_copy_loop:
    beq $t2, $zero, if_init_vars
    lw $t3, 0($t0)
    sw $t3, 0($t1)
    addi $t0, $t0, 4
    addi $t1, $t1, 4
    addi $t2, $t2, -1
    j if_copy_loop

if_init_vars:
    li $t0, 1
    sw $t0, turn_number
    sw $zero, landed_count
    sw $zero, incidents_count
    sw $zero, tcas_warnings
    sw $zero, runway_reserved_by
    sw $zero, game_over_flag
    sw $zero, total_commands
    sw $zero, current_score
    jr $ra

# ==============================================================================
# PROCEDIMENTO: get_aircraft_addr
# Descricao: Calcula o endereco base em fleet_matrix da aeronave de indice 0..5.
# Entradas: $a0 = indice (0..5)
# Saidas:   $v0 = endereco base (fleet_matrix + idx * 24)
# ==============================================================================
get_aircraft_addr:
    sll $t0, $a0, 1                 # 2 * idx
    add $t0, $t0, $a0               # 3 * idx
    sll $t0, $t0, 3                 # 24 * idx
    la $v0, fleet_matrix
    add $v0, $v0, $t0
    jr $ra

# ==============================================================================
# PROCEDIMENTO: read_safe_int
# Descricao: Le uma linha via syscall 8 (read_string), rejeita entradas vazias,
#            nao numericas ou fora do intervalo [min, max]. Nao usa syscall 5.
# Entradas: $a0 = valor minimo aceito, $a1 = valor maximo aceito
# Saidas:   $v0 = inteiro lido (se valido), $v1 = 1 (valido) ou 0 (invalido)
# ==============================================================================
read_safe_int:
    addi $sp, $sp, -8
    sw $s0, 0($sp)
    sw $s1, 4($sp)

    move $s0, $a0
    move $s1, $a1

    li $v0, 8
    la $a0, input_buffer
    li $a1, 64
    syscall

    la $t0, input_buffer

rsi_skip_lead:
    lb $t1, 0($t0)
    li $t4, 32                      # ' '
    beq $t1, $t4, rsi_adv_lead
    li $t4, 9                       # '\t'
    beq $t1, $t4, rsi_adv_lead
    li $t4, 13                      # '\r'
    beq $t1, $t4, rsi_adv_lead
    j rsi_start_digits

rsi_adv_lead:
    addi $t0, $t0, 1
    j rsi_skip_lead

rsi_start_digits:
    li $t2, 0
    li $t3, 0

rsi_digit_loop:
    lb $t1, 0($t0)
    beq $t1, $zero, rsi_check_trail
    li $t4, 10                      # '\n'
    beq $t1, $t4, rsi_check_trail
    li $t4, 32                      # ' '
    beq $t1, $t4, rsi_check_trail
    li $t4, 9                       # '\t'
    beq $t1, $t4, rsi_check_trail
    li $t4, 13                      # '\r'
    beq $t1, $t4, rsi_check_trail

    li $t4, 48                      # '0'
    blt $t1, $t4, rsi_invalid
    li $t4, 57                      # '9'
    bgt $t1, $t4, rsi_invalid

    li $t4, 6
    bge $t3, $t4, rsi_invalid

    addi $t1, $t1, -48
    mul $t2, $t2, 10
    add $t2, $t2, $t1
    addi $t3, $t3, 1
    addi $t0, $t0, 1
    j rsi_digit_loop

rsi_check_trail:
    beq $t3, $zero, rsi_invalid

rsi_trail_loop:
    lb $t1, 0($t0)
    beq $t1, $zero, rsi_check_range
    li $t4, 10
    beq $t1, $t4, rsi_check_range
    li $t4, 32
    beq $t1, $t4, rsi_adv_trail
    li $t4, 9
    beq $t1, $t4, rsi_adv_trail
    li $t4, 13
    beq $t1, $t4, rsi_adv_trail
    j rsi_invalid

rsi_adv_trail:
    addi $t0, $t0, 1
    j rsi_trail_loop

rsi_check_range:
    blt $t2, $s0, rsi_invalid
    bgt $t2, $s1, rsi_invalid

    move $v0, $t2
    li $v1, 1
    j rsi_exit

rsi_invalid:
    li $v0, 0
    li $v1, 0

rsi_exit:
    lw $s0, 0($sp)
    lw $s1, 4($sp)
    addi $sp, $sp, 8
    jr $ra

# ==============================================================================
# PROCEDIMENTO: play_sound
# Descricao: Emite feedback sonoro MIDI discreto via syscall 31.
# Entradas: $a0 = tipo (0=aceito, 1=erro, 2=pouso, 3=atencao, 4=emergencia)
# ==============================================================================
play_sound:
    li $t0, 0
    beq $a0, $t0, ps_ok
    li $t0, 1
    beq $a0, $t0, ps_err
    li $t0, 2
    beq $a0, $t0, ps_land
    li $t0, 3
    beq $a0, $t0, ps_warn
    li $a0, 42
    li $a1, 350
    li $a2, 80
    li $a3, 100
    j ps_emit
ps_ok:
    li $a0, 72
    li $a1, 90
    li $a2, 112
    li $a3, 70
    j ps_emit
ps_err:
    li $a0, 45
    li $a1, 140
    li $a2, 115
    li $a3, 80
    j ps_emit
ps_land:
    li $a0, 84
    li $a1, 220
    li $a2, 9
    li $a3, 90
    j ps_emit
ps_warn:
    li $a0, 62
    li $a1, 220
    li $a2, 81
    li $a3, 85
ps_emit:
    li $v0, 31
    syscall
    jr $ra

# ==============================================================================
# PROCEDIMENTO: add_score
# Descricao: Atualiza a pontuacao global current_score somando o delta em $a0.
# Entradas: $a0 = variacao de pontos (positiva ou negativa)
# ==============================================================================
add_score:
    lw $t0, current_score
    add $t0, $t0, $a0
    sw $t0, current_score
    jr $ra

# ==============================================================================
# PROCEDIMENTO: render_ascii_radar
# Descricao: Imprime as secoes organizadas [2] Cabecalho do Setor,
#            [3] Radar 2D ASCII com legenda e [4] Tabela de Telemetria.
# ==============================================================================
render_ascii_radar:
    addi $sp, $sp, -24
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)
    sw $s2, 12($sp)
    sw $s3, 16($sp)
    sw $s4, 20($sp)

    # --- Secao [2] Cabecalho do Setor ---
    li $v0, 4
    la $a0, str_sec2_hdr
    syscall
    li $v0, 1
    lw $a0, turn_number
    syscall
    li $v0, 4
    la $a0, str_turn_of
    syscall

    lw $t0, active_scenario
    li $t1, 1
    beq $t0, $t1, rar_sc1
    li $t1, 2
    beq $t0, $t1, rar_sc2
    la $a0, str_scen_3_name
    j rar_sc_pr
rar_sc1:
    la $a0, str_scen_1_name
    j rar_sc_pr
rar_sc2:
    la $a0, str_scen_2_name
rar_sc_pr:
    li $v0, 4
    syscall

    li $v0, 4
    la $a0, str_score_lbl
    syscall
    li $v0, 1
    lw $a0, current_score
    syscall
    li $v0, 4
    la $a0, str_pts_lbl
    syscall

    # Linha de status da pista e contadores
    li $v0, 4
    la $a0, str_status_bar1
    syscall
    lw $t0, runway_reserved_by
    beq $t0, $zero, rar_pista_free
    li $v0, 4
    la $a0, str_pista_res1
    syscall
    addi $a0, $t0, -1
    jal get_aircraft_addr
    lw $a0, 0($v0)
    li $v0, 1
    syscall
    li $v0, 4
    la $a0, str_pista_res2
    syscall
    j rar_contadores

rar_pista_free:
    li $v0, 4
    la $a0, str_pista_livre
    syscall

rar_contadores:
    li $v0, 4
    la $a0, str_status_bar2
    syscall
    li $v0, 1
    lw $a0, landed_count
    syscall
    li $v0, 4
    la $a0, str_status_bar3
    syscall
    li $v0, 1
    lw $a0, tcas_warnings
    syscall
    li $v0, 4
    la $a0, str_status_bar4
    syscall
    li $v0, 1
    lw $a0, incidents_count
    syscall
    li $v0, 4
    la $a0, str_newline
    syscall

    # --- Secao [3] Radar de Aproximacao 2D (ASCII) ---
    li $v0, 4
    la $a0, str_sec3_hdr
    syscall
    li $v0, 4
    la $a0, str_radar_border
    syscall

    li $s0, 4000
rar_alt_loop:
    li $t0, 1000
    blt $s0, $t0, rar_grid_footer

    li $t0, 4000
    beq $s0, $t0, rar_lbl_4000
    li $t0, 3000
    beq $s0, $t0, rar_lbl_3000
    li $t0, 2000
    beq $s0, $t0, rar_lbl_2000
    la $a0, str_alt_1000
    j rar_print_lbl
rar_lbl_4000:
    la $a0, str_alt_4000
    j rar_print_lbl
rar_lbl_3000:
    la $a0, str_alt_3000
    j rar_print_lbl
rar_lbl_2000:
    la $a0, str_alt_2000
rar_print_lbl:
    li $v0, 4
    syscall

    li $s1, 0
rar_dist_loop:
    li $t0, 10
    bgt $s1, $t0, rar_alt_next_line

    li $s2, 0
    li $s3, -1
    li $s4, 0

rar_scan_planes:
    li $t0, 6
    beq $s4, $t0, rar_draw_cell

    move $a0, $s4
    jal get_aircraft_addr
    move $t1, $v0

    lw $t2, 16($t1)                 # STATE
    beq $t2, $zero, rar_scan_next
    li $t3, 4
    beq $t2, $t3, rar_scan_next
    li $t3, 6
    beq $t2, $t3, rar_scan_next

    lw $t2, 4($t1)                  # ALT
    bne $t2, $s0, rar_scan_next
    lw $t2, 8($t1)                  # DIST
    bne $t2, $s1, rar_scan_next

    addi $s2, $s2, 1
    move $s3, $s4

rar_scan_next:
    addi $s4, $s4, 1
    j rar_scan_planes

rar_draw_cell:
    beq $s2, $zero, rar_cell_zero
    li $t0, 1
    bgt $s2, $t0, rar_cell_two_plus

    li $v0, 4
    la $a0, str_cell_lbrack
    syscall

    li $v0, 1
    addi $a0, $s3, 1
    syscall

    move $a0, $s3
    jal get_aircraft_addr
    move $t1, $v0
    lw $t2, 20($t1)                 # ALERT
    lw $t3, 16($t1)                 # STATE

    bne $t2, $zero, rar_sym_alert
    li $t4, 5
    beq $t3, $t4, rar_sym_alert
    li $t4, 3
    beq $t3, $t4, rar_sym_clr
    li $t4, 2
    beq $t3, $t4, rar_sym_orb
    li $a0, 32                      # ' '
    j rar_print_sym
rar_sym_alert:
    li $a0, 33                      # '!'
    j rar_print_sym
rar_sym_clr:
    li $a0, 42                      # '*'
    j rar_print_sym
rar_sym_orb:
    li $a0, 64                      # '@'
rar_print_sym:
    li $v0, 11
    syscall

    li $v0, 4
    la $a0, str_cell_rbrack
    syscall
    j rar_dist_next

rar_cell_zero:
    li $t0, 1000
    bne $s0, $t0, rar_cell_blank
    bne $s1, $zero, rar_cell_blank
    li $v0, 4
    la $a0, str_cell_runway
    syscall
    j rar_dist_next

rar_cell_blank:
    li $v0, 4
    la $a0, str_cell_empty
    syscall
    j rar_dist_next

rar_cell_two_plus:
    li $v0, 4
    la $a0, str_cell_multi
    syscall

rar_dist_next:
    addi $s1, $s1, 1
    j rar_dist_loop

rar_alt_next_line:
    li $v0, 4
    la $a0, str_newline
    syscall
    addi $s0, $s0, -1000
    j rar_alt_loop

rar_grid_footer:
    li $v0, 4
    la $a0, str_radar_border
    syscall
    li $v0, 4
    la $a0, str_radar_axis
    syscall
    li $v0, 4
    la $a0, str_radar_legend
    syscall

    # --- Secao [4] Tabela de Telemetria da Frota ---
    li $v0, 4
    la $a0, str_sec4_hdr
    syscall

    li $s0, 0
rar_tbl_loop:
    li $t0, 6
    beq $s0, $t0, rar_done

    move $a0, $s0
    jal get_aircraft_addr
    move $s1, $v0

    li $v0, 4
    la $a0, str_sp1
    syscall
    li $v0, 1
    addi $a0, $s0, 1
    syscall
    li $v0, 4
    la $a0, str_sp2
    syscall

    li $v0, 4
    la $a0, str_voo_prefix
    syscall
    li $v0, 1
    lw $a0, 0($s1)
    syscall
    li $v0, 4
    la $a0, str_pipe_sp
    syscall

    lw $s2, 16($s1)
    li $t0, 4
    beq $s2, $t0, rar_tbl_na_pos
    li $t0, 6
    beq $s2, $t0, rar_tbl_na_pos

    li $v0, 4
    la $a0, str_sp3
    syscall
    li $v0, 1
    lw $a0, 4($s1)
    syscall
    li $v0, 4
    la $a0, str_pipe_sp
    syscall

    lw $t1, 8($s1)
    li $t2, 10
    bge $t1, $t2, rar_dist_2dig
    li $v0, 4
    la $a0, str_sp7
    syscall
    j rar_print_dist_val
rar_dist_2dig:
    li $v0, 4
    la $a0, str_sp6
    syscall
rar_print_dist_val:
    li $v0, 1
    move $a0, $t1
    syscall
    j rar_tbl_fuel

rar_tbl_na_pos:
    li $v0, 4
    la $a0, str_na_alt
    syscall
    li $v0, 4
    la $a0, str_pipe_sp
    syscall
    li $v0, 4
    la $a0, str_na_dist
    syscall

rar_tbl_fuel:
    li $v0, 4
    la $a0, str_pipe_sp
    syscall
    lw $t1, 12($s1)
    li $t2, 10
    bge $t1, $t2, rar_fuel_2dig
    li $v0, 4
    la $a0, str_sp3
    syscall
    j rar_print_fuel_val
rar_fuel_2dig:
    li $v0, 4
    la $a0, str_sp2
    syscall
rar_print_fuel_val:
    li $v0, 1
    move $a0, $t1
    syscall

    li $v0, 4
    la $a0, str_pipe_sp
    syscall

    beq $s2, $zero, rar_st0
    li $t0, 1
    beq $s2, $t0, rar_st1
    li $t0, 2
    beq $s2, $t0, rar_st2
    li $t0, 3
    beq $s2, $t0, rar_st3
    li $t0, 4
    beq $s2, $t0, rar_st4
    li $t0, 5
    beq $s2, $t0, rar_st5
    la $a0, str_st_acc
    j rar_print_st
rar_st0:
    la $a0, str_st_wait
    j rar_print_st
rar_st1:
    la $a0, str_st_app
    j rar_print_st
rar_st2:
    la $a0, str_st_orb
    j rar_print_st
rar_st3:
    la $a0, str_st_clr
    j rar_print_st
rar_st4:
    la $a0, str_st_lnd
    j rar_print_st
rar_st5:
    la $a0, str_st_may
rar_print_st:
    li $v0, 4
    syscall

    li $v0, 4
    la $a0, str_pipe_sp
    syscall

    lw $t1, 20($s1)
    li $t0, 1
    beq $t1, $t0, rar_al1
    li $t0, 2
    beq $t1, $t0, rar_al2
    li $t0, 3
    beq $t1, $t0, rar_al3
    la $a0, str_al_ok
    j rar_print_al
rar_al1:
    la $a0, str_al_mayday
    j rar_print_al
rar_al2:
    la $a0, str_al_tcas
    j rar_print_al
rar_al3:
    la $a0, str_al_arrem
rar_print_al:
    li $v0, 4
    syscall

    li $v0, 4
    la $a0, str_newline
    syscall

    addi $s0, $s0, 1
    j rar_tbl_loop

rar_done:
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    lw $s2, 12($sp)
    lw $s3, 16($sp)
    lw $s4, 20($sp)
    addi $sp, $sp, 24
    jr $ra

# ==============================================================================
# PROCEDIMENTO: process_controller_cmd
# Descricao: Exibe Secao [5] Painel de Comando da Torre (0..8), permite
#            avancar turno direto (7), consultar manual (8) ou comandar voo.
#            Quando turno avanca, abre Secao [1] Caixa de Radio / Eventos.
# Saidas:   $v0 = 1 (turno executado), 0 (usuario encerrou)
# ==============================================================================
process_controller_cmd:
    addi $sp, $sp, -16
    sw $ra, 0($sp)
    sw $s0, 4($sp)                  # slot escolhido (1..6)
    sw $s1, 8($sp)                  # endereco base da aeronave
    sw $s2, 12($sp)                 # comando escolhido (1..6)

pcc_select_plane:
    li $v0, 4
    la $a0, str_sec5_panel
    syscall

    li $a0, 0
    li $a1, 8
    jal read_safe_int
    bne $v1, $zero, pcc_slot_valid_num

    li $v0, 4
    la $a0, str_err_input
    syscall
    li $a0, 1
    jal play_sound
    j pcc_select_plane

pcc_slot_valid_num:
    beq $v0, $zero, pcc_user_quit
    li $t0, 7
    beq $v0, $t0, pcc_advance_all
    li $t0, 8
    beq $v0, $t0, pcc_open_manual

    move $s0, $v0                   # slot 1..6
    addi $a0, $s0, -1
    jal get_aircraft_addr
    move $s1, $v0

    lw $t0, 16($s1)                 # STATE
    beq $t0, $zero, pcc_err_wait
    li $t1, 4
    beq $t0, $t1, pcc_err_landed
    li $t1, 6
    beq $t0, $t1, pcc_err_acc
    j pcc_select_cmd

pcc_open_manual:
    jal print_help_manual
    j pcc_select_plane

pcc_advance_all:
    li $v0, 4
    la $a0, str_box_radio_hdr
    syscall
    li $v0, 4
    la $a0, str_box_radio_all
    syscall
    li $a0, 0
    jal play_sound
    j pcc_cmd_accepted

pcc_err_wait:
    li $v0, 4
    la $a0, str_err_wait
    syscall
    li $a0, 1
    jal play_sound
    j pcc_select_plane

pcc_err_landed:
    li $v0, 4
    la $a0, str_err_landed
    syscall
    li $a0, 1
    jal play_sound
    j pcc_select_plane

pcc_err_acc:
    li $v0, 4
    la $a0, str_err_accident
    syscall
    li $a0, 1
    jal play_sound
    j pcc_select_plane

pcc_select_cmd:
    # Resumo da aeronave selecionada antes das opcoes
    li $v0, 4
    la $a0, str_sel_summary1
    syscall
    li $v0, 1
    lw $a0, 0($s1)
    syscall
    li $v0, 4
    la $a0, str_sel_summary2
    syscall
    li $v0, 1
    lw $a0, 4($s1)
    syscall
    li $v0, 4
    la $a0, str_sel_summary3
    syscall
    li $v0, 1
    lw $a0, 8($s1)
    syscall
    li $v0, 4
    la $a0, str_sel_summary4
    syscall
    li $v0, 1
    lw $a0, 12($s1)
    syscall
    li $v0, 4
    la $a0, str_sel_summary5
    syscall

    li $v0, 4
    la $a0, str_menu_opts
    syscall

    li $a0, 0
    li $a1, 6
    jal read_safe_int
    bne $v1, $zero, pcc_cmd_valid_num

    li $v0, 4
    la $a0, str_err_input
    syscall
    li $a0, 1
    jal play_sound
    j pcc_select_cmd

pcc_cmd_valid_num:
    beq $v0, $zero, pcc_select_plane
    move $s2, $v0

    li $t0, 1
    beq $s2, $t0, pcc_do_descend
    li $t0, 2
    beq $s2, $t0, pcc_do_climb
    li $t0, 3
    beq $s2, $t0, pcc_do_orbit
    li $t0, 4
    beq $s2, $t0, pcc_do_land
    li $t0, 5
    beq $s2, $t0, pcc_do_go_around
    j pcc_do_maintain                # comando 6

# --- Comando 1: Reduzir altitude (-1000 ft) ---
pcc_do_descend:
    lw $t0, 4($s1)
    li $t1, 1000
    ble $t0, $t1, pcc_rej_min_alt
    addi $t0, $t0, -1000
    sw $t0, 4($s1)

    lw $t2, 16($s1)
    li $t3, 2
    bne $t2, $t3, pcc_desc_msg
    lw $t4, 12($s1)
    li $t5, 3
    ble $t4, $t5, pcc_desc_mayday
    li $t3, 1
    sw $t3, 16($s1)
    j pcc_desc_msg
pcc_desc_mayday:
    li $t3, 5
    sw $t3, 16($s1)
pcc_desc_msg:
    li $v0, 4
    la $a0, str_box_radio_hdr
    syscall
    li $v0, 4
    la $a0, str_ok_desc
    syscall
    li $v0, 1
    lw $a0, 0($s1)
    syscall
    li $v0, 4
    la $a0, str_ok_desc2
    syscall
    li $v0, 1
    lw $a0, 4($s1)
    syscall
    li $v0, 4
    la $a0, str_ft_nl
    syscall
    li $a0, 0
    jal play_sound
    j pcc_cmd_accepted

pcc_rej_min_alt:
    li $v0, 4
    la $a0, str_err_min_alt
    syscall
    li $a0, 1
    jal play_sound
    j pcc_select_cmd

# --- Comando 2: Subir altitude (+1000 ft) ---
pcc_do_climb:
    lw $t0, 4($s1)
    li $t1, 4000
    bge $t0, $t1, pcc_rej_max_alt
    addi $t0, $t0, 1000
    sw $t0, 4($s1)

    lw $t2, runway_reserved_by
    bne $t2, $s0, pcc_climb_chk_orb
    sw $zero, runway_reserved_by
pcc_climb_chk_orb:
    lw $t2, 16($s1)
    li $t3, 2
    beq $t2, $t3, pcc_climb_set_app
    li $t3, 3
    beq $t2, $t3, pcc_climb_set_app
    j pcc_climb_msg
pcc_climb_set_app:
    lw $t4, 12($s1)
    li $t5, 3
    ble $t4, $t5, pcc_climb_mayday
    li $t3, 1
    sw $t3, 16($s1)
    j pcc_climb_msg
pcc_climb_mayday:
    li $t3, 5
    sw $t3, 16($s1)
pcc_climb_msg:
    li $v0, 4
    la $a0, str_box_radio_hdr
    syscall
    li $v0, 4
    la $a0, str_ok_desc
    syscall
    li $v0, 1
    lw $a0, 0($s1)
    syscall
    li $v0, 4
    la $a0, str_ok_climb2
    syscall
    li $v0, 1
    lw $a0, 4($s1)
    syscall
    li $v0, 4
    la $a0, str_ft_nl
    syscall
    li $a0, 0
    jal play_sound
    j pcc_cmd_accepted

pcc_rej_max_alt:
    li $v0, 4
    la $a0, str_err_max_alt
    syscall
    li $a0, 1
    jal play_sound
    j pcc_select_cmd

# --- Comando 3: Alternar espera em orbita ---
pcc_do_orbit:
    lw $t0, 16($s1)
    li $t1, 2
    beq $t0, $t1, pcc_leave_orbit

    lw $t2, runway_reserved_by
    bne $t2, $s0, pcc_enter_orbit
    sw $zero, runway_reserved_by
pcc_enter_orbit:
    li $t1, 2
    sw $t1, 16($s1)
    li $v0, 4
    la $a0, str_box_radio_hdr
    syscall
    li $v0, 4
    la $a0, str_ok_orb_in
    syscall
    li $v0, 1
    lw $a0, 0($s1)
    syscall
    li $v0, 4
    la $a0, str_ok_orb_in2
    syscall
    li $a0, 0
    jal play_sound
    j pcc_cmd_accepted

pcc_leave_orbit:
    lw $t4, 12($s1)
    li $t5, 3
    ble $t4, $t5, pcc_leave_mayday
    li $t1, 1
    sw $t1, 16($s1)
    j pcc_leave_msg
pcc_leave_mayday:
    li $t1, 5
    sw $t1, 16($s1)
pcc_leave_msg:
    li $v0, 4
    la $a0, str_box_radio_hdr
    syscall
    li $v0, 4
    la $a0, str_ok_orb_in
    syscall
    li $v0, 1
    lw $a0, 0($s1)
    syscall
    li $v0, 4
    la $a0, str_ok_orb_out2
    syscall
    li $a0, 0
    jal play_sound
    j pcc_cmd_accepted

# --- Comando 4: Autorizar pouso ---
pcc_do_land:
    lw $t0, 4($s1)
    li $t1, 1000
    bne $t0, $t1, pcc_rej_lnd_alt

    lw $t0, 8($s1)
    li $t1, 3
    bgt $t0, $t1, pcc_rej_lnd_dist

    lw $t0, 16($s1)
    li $t1, 3
    beq $t0, $t1, pcc_rej_lnd_dup

    lw $t0, runway_reserved_by
    bne $t0, $zero, pcc_rej_lnd_busy

    li $t1, 3
    sw $t1, 16($s1)
    sw $s0, runway_reserved_by
    li $v0, 4
    la $a0, str_box_radio_hdr
    syscall
    li $v0, 4
    la $a0, str_ok_desc
    syscall
    li $v0, 1
    lw $a0, 0($s1)
    syscall
    li $v0, 4
    la $a0, str_ok_clr2
    syscall
    li $a0, 0
    jal play_sound
    j pcc_cmd_accepted

pcc_rej_lnd_alt:
    li $v0, 4
    la $a0, str_err_lnd_alt
    syscall
    li $a0, 1
    jal play_sound
    j pcc_select_cmd

pcc_rej_lnd_dist:
    li $v0, 4
    la $a0, str_err_lnd_dist
    syscall
    li $a0, 1
    jal play_sound
    j pcc_select_cmd

pcc_rej_lnd_dup:
    li $v0, 4
    la $a0, str_err_lnd_dup
    syscall
    li $a0, 1
    jal play_sound
    j pcc_select_cmd

pcc_rej_lnd_busy:
    li $v0, 4
    la $a0, str_err_lnd_busy
    syscall
    li $a0, 1
    jal play_sound
    j pcc_select_cmd

# --- Comando 5: Arremeter (+1000 ft, +3 NM, -15 pts) ---
pcc_do_go_around:
    lw $t0, 4($s1)
    addi $t0, $t0, 1000
    li $t1, 4000
    ble $t0, $t1, pcc_ga_alt_ok
    li $t0, 4000
pcc_ga_alt_ok:
    sw $t0, 4($s1)

    lw $t0, 8($s1)
    addi $t0, $t0, 3
    li $t1, 10
    ble $t0, $t1, pcc_ga_dist_ok
    li $t0, 10
pcc_ga_dist_ok:
    sw $t0, 8($s1)

    lw $t2, runway_reserved_by
    bne $t2, $s0, pcc_ga_state
    sw $zero, runway_reserved_by
pcc_ga_state:
    lw $t4, 12($s1)
    li $t5, 3
    ble $t4, $t5, pcc_ga_mayday
    li $t1, 1
    sw $t1, 16($s1)
    j pcc_ga_msg
pcc_ga_mayday:
    li $t1, 5
    sw $t1, 16($s1)
pcc_ga_msg:
    li $a0, -15
    jal add_score
    li $v0, 4
    la $a0, str_box_radio_hdr
    syscall
    li $v0, 4
    la $a0, str_ok_desc
    syscall
    li $v0, 1
    lw $a0, 0($s1)
    syscall
    li $v0, 4
    la $a0, str_ok_go_cmd2
    syscall
    li $a0, 3
    jal play_sound
    j pcc_cmd_accepted

# --- Comando 6: Manter curso da aeronave ---
pcc_do_maintain:
    li $v0, 4
    la $a0, str_box_radio_hdr
    syscall
    li $v0, 4
    la $a0, str_ok_desc
    syscall
    li $v0, 1
    lw $a0, 0($s1)
    syscall
    li $v0, 4
    la $a0, str_ok_keep2
    syscall
    li $a0, 0
    jal play_sound

pcc_cmd_accepted:
    lw $t0, total_commands
    addi $t0, $t0, 1
    sw $t0, total_commands
    li $v0, 1
    j pcc_exit

pcc_user_quit:
    li $t0, 3
    sw $t0, game_over_flag
    li $v0, 0

pcc_exit:
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    lw $s2, 12($sp)
    addi $sp, $sp, 16
    jr $ra

# ==============================================================================
# PROCEDIMENTO: check_separation_and_collisions
# Descricao: Verifica pares ativos (i < j) na mesma altitude.
#            Distancia == 0 => colisao (-300 pts); |Dist_i - Dist_j| == 1 => TCAS! (-25 pts).
# Saidas:   $v0 = quantidade de eventos de separacao/colisao emitidos
# ==============================================================================
check_separation_and_collisions:
    addi $sp, $sp, -28
    sw $ra, 0($sp)
    sw $s0, 4($sp)                  # i
    sw $s1, 8($sp)                  # j
    sw $s2, 12($sp)                 # addr i
    sw $s3, 16($sp)                 # addr j
    sw $s4, 20($sp)                 # prioridade sonora (0, 1, 2)
    sw $s5, 24($sp)                 # contador de eventos impressos

    li $s0, 0
    li $s4, 0
    li $s5, 0

csc_outer:
    li $t0, 5
    bge $s0, $t0, csc_done

    move $a0, $s0
    jal get_aircraft_addr
    move $s2, $v0

    lw $t1, 16($s2)
    beq $t1, $zero, csc_next_i
    li $t2, 4
    beq $t1, $t2, csc_next_i
    li $t2, 6
    beq $t1, $t2, csc_next_i

    addi $s1, $s0, 1
csc_inner:
    li $t0, 6
    bge $s1, $t0, csc_next_i

    move $a0, $s1
    jal get_aircraft_addr
    move $s3, $v0

    lw $t1, 16($s3)
    beq $t1, $zero, csc_next_j
    li $t2, 4
    beq $t1, $t2, csc_next_j
    li $t2, 6
    beq $t1, $t2, csc_next_j

    lw $t3, 4($s2)
    lw $t4, 4($s3)
    bne $t3, $t4, csc_next_j

    lw $t3, 8($s2)
    lw $t4, 8($s3)
    sub $t5, $t3, $t4
    bgez $t5, csc_abs_ok
    sub $t5, $zero, $t5
csc_abs_ok:
    beq $t5, $zero, csc_collision
    li $t6, 1
    beq $t5, $t6, csc_tcas
    j csc_next_j

csc_collision:
    li $t0, 6
    sw $t0, 16($s2)
    sw $t0, 16($s3)
    li $t0, 2
    sw $t0, 20($s2)
    sw $t0, 20($s3)

    lw $t1, runway_reserved_by
    addi $t2, $s0, 1
    beq $t1, $t2, csc_clr_rwy
    addi $t2, $s1, 1
    bne $t1, $t2, csc_upd_col_cnt
csc_clr_rwy:
    sw $zero, runway_reserved_by

csc_upd_col_cnt:
    lw $t0, incidents_count
    addi $t0, $t0, 2
    sw $t0, incidents_count
    li $t0, 2
    sw $t0, game_over_flag

    li $a0, -300
    jal add_score

    li $v0, 4
    la $a0, str_evt_col1
    syscall
    li $v0, 1
    lw $a0, 0($s2)
    syscall
    li $v0, 4
    la $a0, str_evt_tcas2
    syscall
    li $v0, 1
    lw $a0, 0($s3)
    syscall
    li $v0, 4
    la $a0, str_evt_col3
    syscall

    addi $s5, $s5, 1
    li $s4, 2
    j csc_next_j

csc_tcas:
    li $t0, 2
    sw $t0, 20($s2)
    sw $t0, 20($s3)

    lw $t0, tcas_warnings
    addi $t0, $t0, 1
    sw $t0, tcas_warnings

    li $a0, -25
    jal add_score

    li $v0, 4
    la $a0, str_evt_tcas1
    syscall
    li $v0, 1
    lw $a0, 0($s2)
    syscall
    li $v0, 4
    la $a0, str_evt_tcas2
    syscall
    li $v0, 1
    lw $a0, 0($s3)
    syscall
    li $v0, 4
    la $a0, str_evt_tcas3
    syscall

    addi $s5, $s5, 1
    bne $s4, $zero, csc_next_j
    li $s4, 1

csc_next_j:
    addi $s1, $s1, 1
    j csc_inner

csc_next_i:
    addi $s0, $s0, 1
    j csc_outer

csc_done:
    li $t0, 2
    beq $s4, $t0, csc_snd_alarm
    li $t0, 1
    beq $s4, $t0, csc_snd_warn
    j csc_exit

csc_snd_alarm:
    li $a0, 4
    jal play_sound
    j csc_exit

csc_snd_warn:
    li $a0, 3
    jal play_sound

csc_exit:
    move $v0, $s5
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    lw $s2, 12($sp)
    lw $s3, 16($sp)
    lw $s4, 20($sp)
    lw $s5, 24($sp)
    addi $sp, $sp, 28
    jr $ra

# ==============================================================================
# PROCEDIMENTO: update_simulation_turn
# Descricao: Atualiza fisica do turno (combustivel, avanco, pouso, arremetida,
#            pane seca, colisoes, ondas e fim de jogo) e fecha Secao [1].
# ==============================================================================
update_simulation_turn:
    addi $sp, $sp, -24
    sw $ra, 0($sp)
    sw $s0, 4($sp)                  # indice 0..5
    sw $s1, 8($sp)                  # endereco base da aeronave
    sw $s2, 12($sp)                 # slot 1..6
    sw $s3, 16($sp)                 # contador de eventos impressos na Caixa [1]
    sw $s4, 20($sp)                 # auxiliar para bonus de pouso

    li $s3, 0
    li $s0, 0

ust_plane_loop:
    li $t0, 6
    beq $s0, $t0, ust_check_sep

    move $a0, $s0
    jal get_aircraft_addr
    move $s1, $v0
    addi $s2, $s0, 1

    lw $t0, 16($s1)                 # STATE
    beq $t0, $zero, ust_next_plane
    li $t1, 4
    beq $t0, $t1, ust_next_plane
    li $t1, 6
    beq $t0, $t1, ust_next_plane

    li $t1, 5
    beq $t0, $t1, ust_keep_mayday_al
    li $t1, 3
    bne $t0, $t1, ust_clear_al
    lw $t3, 12($s1)
    li $t4, 3
    ble $t3, $t4, ust_keep_mayday_al
ust_clear_al:
    sw $zero, 20($s1)
    j ust_move_plane
ust_keep_mayday_al:
    li $t2, 1
    sw $t2, 20($s1)

ust_move_plane:
    lw $t3, 12($s1)
    addi $t3, $t3, -1
    bgez $t3, ust_fuel_nonneg
    li $t3, 0
ust_fuel_nonneg:
    sw $t3, 12($s1)

    li $t1, 2
    beq $t0, $t1, ust_check_fuel

    lw $t4, 8($s1)
    addi $t4, $t4, -1
    sw $t4, 8($s1)

    bgtz $t4, ust_check_fuel

    li $t1, 3
    bne $t0, $t1, ust_auto_go_around
    lw $t5, 4($s1)
    li $t6, 1000
    bne $t5, $t6, ust_auto_go_around

    # Pouso bem-sucedido: +100 + 10 * FUEL restante
    li $t1, 4
    sw $t1, 16($s1)
    sw $zero, 4($s1)
    sw $zero, 8($s1)
    sw $zero, 20($s1)
    sw $zero, runway_reserved_by

    lw $t6, landed_count
    addi $t6, $t6, 1
    sw $t6, landed_count

    lw $t3, 12($s1)
    li $t4, 10
    mul $s4, $t3, $t4
    addi $s4, $s4, 100
    move $a0, $s4
    jal add_score

    li $v0, 4
    la $a0, str_evt_land1
    syscall
    li $v0, 1
    lw $a0, 0($s1)
    syscall
    li $v0, 4
    la $a0, str_evt_land2
    syscall
    li $v0, 1
    move $a0, $s4
    syscall
    li $v0, 4
    la $a0, str_evt_pts_end
    syscall

    addi $s3, $s3, 1
    li $a0, 2
    jal play_sound
    j ust_next_plane

ust_auto_go_around:
    li $t4, 3
    sw $t4, 8($s1)
    lw $t5, 4($s1)
    li $t6, 2000
    bge $t5, $t6, ust_ga_keep_alt
    sw $t6, 4($s1)
ust_ga_keep_alt:
    lw $t6, runway_reserved_by
    bne $t6, $s2, ust_ga_set_state
    sw $zero, runway_reserved_by
ust_ga_set_state:
    li $t1, 1
    sw $t1, 16($s1)
    li $t1, 3
    sw $t1, 20($s1)

    li $a0, -40
    jal add_score

    li $v0, 4
    la $a0, str_evt_auto_ga1
    syscall
    li $v0, 1
    lw $a0, 0($s1)
    syscall
    li $v0, 4
    la $a0, str_evt_auto_ga2
    syscall

    addi $s3, $s3, 1
    li $a0, 3
    jal play_sound

ust_check_fuel:
    lw $t3, 12($s1)
    blez $t3, ust_fuel_empty

    li $t4, 3
    bgt $t3, $t4, ust_next_plane

    lw $t0, 16($s1)
    li $t1, 5
    beq $t0, $t1, ust_next_plane
    li $t1, 3
    beq $t0, $t1, ust_clr_low_fuel
    li $t1, 5
    sw $t1, 16($s1)
    j ust_mark_mayday_al
ust_clr_low_fuel:
    lw $t4, 20($s1)
    bne $t4, $zero, ust_next_plane
ust_mark_mayday_al:
    li $t1, 1
    sw $t1, 20($s1)

    li $v0, 4
    la $a0, str_evt_mayday1
    syscall
    li $v0, 1
    lw $a0, 0($s1)
    syscall
    li $v0, 4
    la $a0, str_evt_mayday2
    syscall
    addi $s3, $s3, 1
    li $a0, 4
    jal play_sound
    j ust_next_plane

ust_fuel_empty:
    li $t1, 6
    sw $t1, 16($s1)
    li $t1, 1
    sw $t1, 20($s1)

    lw $t6, runway_reserved_by
    bne $t6, $s2, ust_fuel_acc_cnt
    sw $zero, runway_reserved_by
ust_fuel_acc_cnt:
    lw $t6, incidents_count
    addi $t6, $t6, 1
    sw $t6, incidents_count
    li $t6, 2
    sw $t6, game_over_flag

    li $a0, -300
    jal add_score

    li $v0, 4
    la $a0, str_evt_fuel1
    syscall
    li $v0, 1
    lw $a0, 0($s1)
    syscall
    li $v0, 4
    la $a0, str_evt_fuel2
    syscall
    addi $s3, $s3, 1
    li $a0, 4
    jal play_sound

ust_next_plane:
    addi $s0, $s0, 1
    j ust_plane_loop

ust_check_sep:
    jal check_separation_and_collisions
    add $s3, $s3, $v0

    lw $t0, game_over_flag
    bne $t0, $zero, ust_close_radio_box

    # Ondas de chegada conforme turno:
    # Turno 2: ativa Slot 5 (se aguardando)
    # Turno 4: ativa Slot 6 (se aguardando)
    lw $t0, turn_number
    li $t1, 2
    beq $t0, $t1, ust_wave_slot5
    li $t1, 4
    beq $t0, $t1, ust_wave_slot6
    j ust_advance_turn

ust_wave_slot5:
    li $a0, 4
    jal get_aircraft_addr
    move $s1, $v0
    lw $t2, 16($s1)
    beq $t2, $zero, ust_activate_wave
    j ust_advance_turn

ust_wave_slot6:
    li $a0, 5
    jal get_aircraft_addr
    move $s1, $v0
    lw $t2, 16($s1)
    bne $t2, $zero, ust_advance_turn

ust_activate_wave:
    li $t2, 1
    sw $t2, 16($s1)
    li $v0, 4
    la $a0, str_evt_wave1
    syscall
    li $v0, 1
    lw $a0, 0($s1)
    syscall
    li $v0, 4
    la $a0, str_evt_wave2
    syscall
    addi $s3, $s3, 1

ust_advance_turn:
    lw $t0, landed_count
    li $t1, 6
    bne $t0, $t1, ust_inc_turn
    li $t2, 1
    sw $t2, game_over_flag
    j ust_close_radio_box

ust_inc_turn:
    lw $t0, turn_number
    li $t1, 25
    bge $t0, $t1, ust_hit_limit
    addi $t0, $t0, 1
    sw $t0, turn_number
    j ust_close_radio_box
ust_hit_limit:
    li $t2, 4
    sw $t2, game_over_flag

ust_close_radio_box:
    bne $s3, $zero, ust_print_ftr
    li $v0, 4
    la $a0, str_box_radio_none
    syscall
ust_print_ftr:
    li $v0, 4
    la $a0, str_box_radio_ftr
    syscall

    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    lw $s2, 12($sp)
    lw $s3, 16($sp)
    lw $s4, 20($sp)
    addi $sp, $sp, 24
    jr $ra

# ==============================================================================
# PROCEDIMENTO: print_final_report
# Descricao: Exibe motivo de encerramento, estatisticas e classificacao final.
# ==============================================================================
print_final_report:
    li $v0, 4
    la $a0, str_fin_hdr
    syscall

    lw $t0, game_over_flag
    li $t1, 1
    beq $t0, $t1, pfr_win
    li $t1, 2
    beq $t0, $t1, pfr_acc
    li $t1, 3
    beq $t0, $t1, pfr_exit
    la $a0, str_fin_lim
    j pfr_print_reason
pfr_win:
    la $a0, str_fin_win
    j pfr_print_reason
pfr_acc:
    la $a0, str_fin_acc
    j pfr_print_reason
pfr_exit:
    la $a0, str_fin_exit
pfr_print_reason:
    li $v0, 4
    syscall

    li $v0, 4
    la $a0, str_fin_stat0
    syscall
    lw $t0, active_scenario
    li $t1, 1
    beq $t0, $t1, pfr_sc1
    li $t1, 2
    beq $t0, $t1, pfr_sc2
    la $a0, str_scen_3_name
    j pfr_sc_pr
pfr_sc1:
    la $a0, str_scen_1_name
    j pfr_sc_pr
pfr_sc2:
    la $a0, str_scen_2_name
pfr_sc_pr:
    li $v0, 4
    syscall

    li $v0, 4
    la $a0, str_fin_stat1
    syscall
    li $v0, 1
    lw $a0, turn_number
    syscall

    li $v0, 4
    la $a0, str_fin_stat2
    syscall
    li $v0, 1
    lw $a0, total_commands
    syscall

    li $v0, 4
    la $a0, str_fin_stat3
    syscall
    li $v0, 1
    lw $a0, landed_count
    syscall

    li $v0, 4
    la $a0, str_fin_stat4
    syscall
    li $v0, 1
    lw $a0, tcas_warnings
    syscall

    li $v0, 4
    la $a0, str_fin_stat5
    syscall
    li $v0, 1
    lw $a0, incidents_count
    syscall

    li $v0, 4
    la $a0, str_fin_stat6
    syscall
    li $v0, 1
    lw $a0, current_score
    syscall

    li $v0, 4
    la $a0, str_fin_rank_lbl
    syscall

    lw $t0, incidents_count
    bgtz $t0, pfr_rk_fail
    lw $t0, game_over_flag
    li $t1, 2
    beq $t0, $t1, pfr_rk_fail
    lw $t0, landed_count
    li $t1, 6
    blt $t0, $t1, pfr_rk_inc

    lw $t0, current_score
    li $t1, 750
    bge $t0, $t1, pfr_rk_s
    li $t1, 650
    bge $t0, $t1, pfr_rk_a
    li $t1, 500
    bge $t0, $t1, pfr_rk_b
    la $a0, str_rank_c
    j pfr_rk_print

pfr_rk_s:
    la $a0, str_rank_s
    j pfr_rk_print
pfr_rk_a:
    la $a0, str_rank_a
    j pfr_rk_print
pfr_rk_b:
    la $a0, str_rank_b
    j pfr_rk_print
pfr_rk_inc:
    la $a0, str_rank_inc
    j pfr_rk_print
pfr_rk_fail:
    la $a0, str_rank_fail

pfr_rk_print:
    li $v0, 4
    syscall
    li $v0, 4
    la $a0, str_fin_ftr
    syscall
    jr $ra
