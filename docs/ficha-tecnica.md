# Ficha Técnica — ATC-MIPS

## 1. Objetivo do Produto
O **ATC-MIPS** é um simulador interativo de controle de tráfego aéreo em **Terminal ASCII**, desenvolvido em Assembly MIPS32 para o **MARS 4.5+**. O usuário escolhe entre 3 cenários operacionais e coordena o pouso seguro de 6 aeronaves em pista única por turnos discretos, gerenciando altitude, espera em órbita, consumo de combustível e separação mínima, sob um sistema de pontuação e ranking final.

---

## 2. Organização da Lógica
Toda a lógica reside em [src/atc_mips.asm](file:///home/BRENO/Documents/Unifesp/aoc/aoc-final/src/atc_mips.asm), estruturada em fluxo modular:
1. **Abertura e Cenários (`print_welcome_briefing`, `select_scenario`, `init_fleet`, `print_help_manual`):** Apresenta o objetivo e os comandos do simulador, permite consultar o manual completo e carrega um dos 3 cenários determinísticos (`Operacao Padrao`, `Hora do Rush` ou `Emerg. MAYDAY`).
2. **Apresentação ASCII em 5 Seções (`render_ascii_radar`, `process_controller_cmd`, `update_simulation_turn`):** Mantém o console organizado a cada ciclo em `[1] Caixa de Rádio/Eventos`, `[2] Cabeçalho do Setor` (com Turno, Cenário e Score), `[3] Radar 2D ASCII + Legenda`, `[4] Tabela de Telemetria` e `[5] Painel de Comando da Torre`.
3. **Entrada Segura (`read_safe_int`):** Lê entradas via `syscall 8` (`read_string`), valida dígitos e intervalos `[$a0, $a1]`, impedindo travamentos com entradas vazias ou não numéricas (sem uso de `syscall 5`).
4. **Simulação, Colisões e Pontuação (`update_simulation_turn`, `check_separation_and_collisions`, `add_score`):** Aplica consumo de combustível (`-1/turno`), avanço longitudinal (`-1 NM` se fora de órbita), pouso (`+100 + 10*FUEL`), arremetida manual (`-15`), arremetida automática (`-40`), `MAYDAY`, pane seca (`-300`), alertas `TCAS!` (`-25`), colisão aérea (`-300`) e ondas nos Turnos 2 e 4.
5. **Encerramento (`print_final_report`):** Mostra estatísticas finais, pontuação e classificação (`RANK S`, `A`, `B`, `C`, `INCOMPLETO` ou `REPROVADO`), encerrando via `syscall 10`.

---

## 3. Estruturas de Dados (Segmento `.data` a partir de `0x10010000`)

| Rótulo | Tamanho | Estrutura | Descrição |
| :--- | :---: | :--- | :--- |
| `fleet_matrix` | `144 B` | `6 × 6` words (`24 B/voo`) | `+0: ID`, `+4: ALT`, `+8: DIST`, `+12: FUEL`, `+16: STATE (0..6)`, `+20: ALERT (0..3)`. Base em `0x10010000`. |
| `scenario_1_data..3` | `432 B` | `3 × 36` words | Dados iniciais determinísticos dos 3 cenários de operação. |
| Variáveis globais | `36 B` | `9` words | `active_scenario`, `turn_number`, `landed_count`, `incidents_count`, `tcas_warnings`, `runway_reserved_by`, `game_over_flag`, `total_commands`, `current_score`. |
| `input_buffer` | `64 B` | Buffer ASCII | Armazena a string lida por `syscall 8` em `read_safe_int`. |

---

## 4. Procedimentos Principais e Uso da Pilha (`$sp`)

| Procedimento | Linhas | Parâmetros / Retorno | Uso de `$sp` e Responsabilidade |
| :--- | :---: | :--- | :--- |
| `main` | 249–299 | — | Orquestra abertura, seleção de cenário, laço principal e encerramento (`syscall 10`). |
| `print_welcome_briefing` | 301–309 | — | Exibe o briefing inicial com objetivo, radar e resumo de comandos. |
| `print_help_manual` | 311–321 | — | Exibe o manual completo de leitura do radar, comandos e pontuação. |
| `select_scenario` | 323–375 | `$v0 = 1..3` ou `0` | Preserva `$ra, $s0` (`8 B`); escolhe cenário, abre manual (`4`) ou sai (`0`). |
| `init_fleet` | 377–420 | `$a0 = cenário (1..3)` | Copia tabela do cenário para `fleet_matrix` e zera contadores e `current_score`. |
| `get_aircraft_addr` | 422–435 | `$a0 = idx` → `$v0 = addr` | Calcula `fleet_matrix + idx * 24` via deslocamentos (`(idx + 2*idx) << 3`). |
| `read_safe_int` | 437–538 | `$a0=min, $a1=max` → `$v0, $v1` | Preserva `$s0..$s1` (`8 B`); lê e valida inteiros via `syscall 8`. |
| `play_sound` | 540–585 | `$a0 = tipo (0..4)` | Emite feedback MIDI discreto via `syscall 31`. |
| `add_score` | 587–596 | `$a0 = delta` | Soma variação positiva ou negativa em `current_score`. |
| `render_ascii_radar` | 598–1030 | — | Preserva `$ra, $s0..$s4` (`24 B`); imprime Seções `[2]`, `[3]` e `[4]`. |
| `process_controller_cmd` | 1032–1501 | `$v0 = 1` ou `0` | Preserva `$ra, $s0..$s2` (`16 B`); exibe Seção `[5]`, trata atalho `7`, ajuda `8` e comandos `1..6`. |
| `check_separation_and_collisions` | 1503–1680 | `$v0 = nº eventos` | Preserva `$ra, $s0..$s5` (`28 B`); verifica pares `(i < j)` na mesma altitude (`TCAS!`/colisão). |
| `update_simulation_turn` | 1682–1979 | — | Preserva `$ra, $s0..$s4` (`24 B`); atualiza voo, pouso, pane seca, ondas e fecha Seção `[1]`. |
| `print_final_report` | 1981–2112 | — | Imprime métricas finais, `current_score` e classificação (`Rank`) do controlador. |

---

## 5. Contagem de Instruções Úteis MIPS e Localização dos Requisitos
Seguindo o critério do enunciado (1 instrução por linha de origem em `.text`, incluindo pseudoinstruções, excluindo linhas vazias, comentários, rótulos isolados, diretivas e `.data`), [src/atc_mips.asm](file:///home/BRENO/Documents/Unifesp/aoc/aoc-final/src/atc_mips.asm) possui **1.388 instruções úteis** (mínimo exigido: `100`):
- `main`: `31` | `print_welcome_briefing`: `4` | `print_help_manual`: `4` | `select_scenario`: `33` | `init_fleet`: `29` | `get_aircraft_addr`: `6` | `read_safe_int`: `69` | `play_sound`: `35` | `add_score`: `4` | `render_ascii_radar`: `332` | `process_controller_cmd`: `375` | `check_separation_and_collisions`: `133` | `update_simulation_turn`: `228` | `print_final_report`: `105`.

**Localização dos requisitos obrigatórios:**
- **Matriz em memória:** `fleet_matrix` e `scenario_1..3_data` (linhas `21–50`); indexação em `get_aircraft_addr` (linhas `422–435`).
- **Decisões e repetições reais:** varredura 2D do radar (linhas `704–840`), validação léxica de dígitos (linhas `465–518`), verificação par-a-par de colisões (linhas `1515–1650`) e atualização de turno (linhas `1693–1959`).
- **Procedimentos, parâmetros e pilha:** 14 procedimentos seguindo `$a*/$v*/$s*/$ra` e preservação em `$sp` nos quadros de pilha.
- **Entradas inválidas e saída limpa:** `read_safe_int` (linhas `437–538`), validações em `process_controller_cmd` e encerramento por opção `0` ou fim da partida (`syscall 10` em `291–299`).

---

## 6. Contribuição dos Integrantes e Síntese de Feedback
- **Contribuições:** Breno — especificação, arquitetura, implementação completa em Assembly MIPS, testes no MARS CLI e documentação *(ajustar se houver outros integrantes antes da entrega final)*.
- **Síntese de feedback e evolução:** Após a primeira versão, removeu-se o display gráfico para concentrar toda a experiência no **Terminal ASCII**, adicionando briefing inicial explicativo, manual consultável a qualquer turno (`8`), atalho direto de avanço de turno (`7`), 3 cenários determinísticos, organização visual em 5 seções e sistema de pontuação com ranking final.
