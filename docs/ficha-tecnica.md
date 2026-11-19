# Ficha Técnica — ATC-MIPS

## 1. Objetivo do Produto
O **ATC-MIPS (v3.0)** é um simulador estratégico de controle de aproximação aérea em **Terminal ASCII**, desenvolvido em Assembly MIPS32 para o **MARS 4.5+**. O usuário escolhe entre 3 fases fixas de dificuldade crescente ou 1 modo aleatório procedural (`syscall 42`) para pousar 6 aeronaves em pista única, administrando altitudes (`1000..4000 ft`), espera em órbita, arremetida tática, 1 turno de taxiamento pós-pouso e o limite crítico `00 NM`.

---

## 2. Organização da Lógica
Toda a lógica encontra-se em [src/atc_mips.asm](file:///home/BRENO/Documents/Unifesp/aoc/aoc-final/src/atc_mips.asm), estruturada em 5 blocos funcionais:
1. **Abertura, Manual e Fases (`print_welcome_briefing`, `print_help_manual`, `select_scenario`, `init_fleet`, `init_random_fleet`, `reset_global_vars`):** Apresenta briefing inicial, oferece 3 fases determinísticas (*Operação Tática*, *Hora do Rush*, *Tempestade MAYDAY*) e 1 modo procedural (`syscall 30/40/42`) livre de colisões no Turno 1.
2. **Apresentação ASCII em 5 Seções (`render_ascii_radar`, `print_scenario_name`):** Mantém o console organizado em `[1] Caixa de Rádio`, `[2] Cabeçalho do Setor` (Turno, Modo, Score, status `LIVRE`/`RESERV`/`OCUPADA(TAXI)`), `[3] Radar 2D ASCII` (`[==]` livre, `[##]` taxi), `[4] Tabela de Telemetria` e `[5] Painel da Torre`.
3. **E/S Segura (`read_safe_int`, `process_controller_cmd`):** Lê via `syscall 8` (sem `syscall 5`), valida atalho `7` (avançar todos), ajuda `8` (manual sem gastar turno), comando `4` (bloqueado durante `runway_cooldown`) e comando `5` (arremetida restrita a `Dist <= 4 NM`, reinserindo o voo em `08 NM`).
4. **Física do Turno e Limite `00 NM` (`update_simulation_turn`, `check_separation_and_collisions`, `add_score`):** Aplica movimento, combustível, pouso (`+100 + 10*FUEL` e `runway_cooldown = 1`), acidente imediato ao cruzar `00 NM` sem autorização (`INVASAO DE PISTA` ou `VIOLACAO DE LIMITE`, `-300 pts`), `MAYDAY`/`PANE SECA`, `TCAS!` (`-25 pts`), colisão (`-300 pts`) e ondas nos Turnos 2 e 4.
5. **Encerramento e Ranking (`print_final_report`):** Exibe estatísticas, pontuação e classificação (`RANK S` a `REPROVADO`), finalizando com `syscall 10`.

---

## 3. Estruturas de Dados (Segmento `.data` a partir de `0x10010000`)

| Rótulo | Tamanho | Estrutura | Descrição |
| :--- | :---: | :--- | :--- |
| `fleet_matrix` | `144 B` | `6 × 6` words (`24 B/voo`) | `+0: ID`, `+4: ALT`, `+8: DIST`, `+12: FUEL`, `+16: STATE (0..6)`, `+20: ALERT (0..3)`. Base `0x10010000`. |
| `scenario_1_data..3` | `432 B` | `3 × 36` words | Dados iniciais determinísticos das Fases 1, 2 e 3. |
| Variáveis globais | `40 B` | `10` words | `active_scenario`, `turn_number`, `landed_count`, `incidents_count`, `tcas_warnings`, `runway_reserved_by`, `runway_cooldown`, `game_over_flag`, `total_commands`, `current_score`. |
| `input_buffer` | `64 B` | Buffer ASCII | Armazena strings lidas por `syscall 8` em `read_safe_int`. |

---

## 4. Procedimentos Principais e Uso da Pilha (`$sp`)

| Procedimento | Linhas | Parâmetros / Retorno | Uso de `$sp` e Responsabilidade |
| :--- | :---: | :--- | :--- |
| `main` | 257–302 | — | Orquestra abertura, seleção de modo, laço de turnos e `syscall 10`. |
| `print_welcome_briefing` | 304–312 | — | Exibe o briefing inicial com objetivo, limites e comandos. |
| `print_help_manual` | 314–324 | — | Exibe manual completo de leitura, regras de limite e pontuação. |
| `select_scenario` | 326–385 | `$v0 = 1..4` ou `0` | Preserva `$ra, $s0` (`8 B`); seleciona fase fixa, RNG ou manual. |
| `reset_global_vars` | 387–403 | — | Zera variáveis globais, `runway_cooldown` e `current_score`. |
| `init_fleet` | 405–443 | `$a0 = 1..3` | Preserva `$ra` (`4 B`); copia tabela da fase para `fleet_matrix`. |
| `init_random_fleet` | 445–632 | — | Preserva `$ra, $s0..$s5` (`28 B`); gera frota via `syscall 30/40/42`. |
| `get_aircraft_addr` | 634–647 | `$a0=idx` → `$v0=addr` | Calcula `fleet_matrix + idx * 24` por deslocamentos (`(idx + 2*idx) << 3`). |
| `read_safe_int` | 649–750 | `$a0=min, $a1=max` → `$v0, $v1` | Preserva `$s0..$s1` (`8 B`); lê e valida inteiros via `syscall 8`. |
| `play_sound` | 752–796 | `$a0 = 0..4` | Emite alertas MIDI discretos via `syscall 31`. |
| `add_score` | 798–806 | `$a0 = delta` | Atualiza `current_score` em memória. |
| `print_scenario_name` | 808–834 | — | Imprime o nome do modo ativo (`1..4`). |
| `render_ascii_radar` | 836–1268 | — | Preserva `$ra, $s0..$s4` (`24 B`); imprime Seções `[2]`, `[3]` e `[4]`. |
| `process_controller_cmd` | 1270–1757 | `$v0 = 1` ou `0` | Preserva `$ra, $s0..$s2` (`16 B`); exibe Seção `[5]`, valida Cmds `1..8`. |
| `check_separation_and_collisions` | 1759–1937 | `$v0 = nº eventos` | Preserva `$ra, $s0..$s5` (`28 B`); verifica pares `(i < j)` (`TCAS!`/colisão). |
| `update_simulation_turn` | 1939–2270 | — | Preserva `$ra, $s0..$s5` (`28 B`); movimento, limite `00 NM`, taxi, ondas. |
| `print_final_report` | 2272–2395 | — | Preserva `$ra` (`4 B`); exibe relatório final, pontuação e Rank. |

---

## 5. Contagem de Instruções Úteis MIPS e Localização dos Requisitos
Pelo critério do enunciado (1 instrução por linha de origem em `.text`, incluindo pseudoinstruções, sem linhas vazias, comentários, rótulos isolados, diretivas ou `.data`), [src/atc_mips.asm](file:///home/BRENO/Documents/Unifesp/aoc/aoc-final/src/atc_mips.asm) possui **1.582 instruções úteis** (mínimo exigido: `100`):
- `main`: `31` | `print_welcome_briefing`: `4` | `print_help_manual`: `4` | `select_scenario`: `37` | `reset_global_vars`: `11` | `init_fleet`: `25` | `init_random_fleet`: `133` | `get_aircraft_addr`: `6` | `read_safe_int`: `69` | `play_sound`: `35` | `add_score`: `4` | `print_scenario_name`: `17` | `render_ascii_radar`: `333` | `process_controller_cmd`: `388` | `check_separation_and_collisions`: `133` | `update_simulation_turn`: `254` | `print_final_report`: `98`.

**Localização dos requisitos obrigatórios:**
- **Matriz em memória:** `fleet_matrix` e tabelas `scenario_1..3_data` (`21–50`); acesso via `get_aircraft_addr` (`634–647`).
- **Decisões e repetições reais:** geração anti-conflito em `init_random_fleet` (`529–556`), varredura 2D do radar (`958–1092`), validação léxica (`677–730`), separação par-a-par (`1772–1907`) e limite `00 NM` (`2014–2118`).
- **Procedimentos, parâmetros e pilha:** 17 procedimentos preservando `$ra` e `$s*` em `$sp`.
- **Entradas inválidas e encerramento:** `read_safe_int` (`649–750`), bloqueios sem perda de turno em `process_controller_cmd` e `syscall 10` (`295–302`).

---

## 6. Contribuição dos Integrantes e Síntese de Feedback
- **Contribuições:** Breno — especificação, implementação completa em Assembly MIPS, bateria de testes no MARS CLI e documentação *(ajustar se houver outros integrantes antes da entrega final)*.
- **Síntese de feedback e evolução:** Após avaliação da versão anterior (considerada permissiva por retornar aeronaves automaticamente em `00 NM`), removeu-se a arremetida automática substituindo-a por acidente crítico no limite da matriz, restringiu-se a arremetida manual a `Dist <= 4 NM` (retornando a `08 NM`), adicionou-se 1 turno obrigatório de taxiamento pós-pouso (`runway_cooldown`), elevaram-se as 3 fases fixas e incluiu-se a Fase 4 aleatória via `syscall 42`.
