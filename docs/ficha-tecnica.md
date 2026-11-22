# Ficha Técnica — ATC-MIPS

## 1. Objetivo do Produto
O **ATC-MIPS** é um simulador de controle de aproximação aérea por turnos em **Terminal ASCII**, desenvolvido em Assembly MIPS32 para o **MARS 4.5+**. O usuário gerencia **4 aeronaves** (`VO-101`..`VO-404`) em uma grade de `4` altitudes (`4000..1000 ft`) × `8` distâncias (`00..07 NM`) para pousar todas na pista única (`1000 ft, 00 NM`) em até 20 turnos, evitando colisão, pane seca e cruzamento de `00 NM` sem autorização.

---

## 2. Organização da Lógica
O código-fonte em [src/atc_mips.asm](file:///home/BRENO/Documents/Unifesp/aoc/aoc-final/src/atc_mips.asm) (646 linhas) foi projetado de forma enxuta e didática, dividido em **6 procedimentos** com nomes explícitos:
1. **Orquestração (`main`):** Imprime a introdução, executa o laço de turnos (`radar → comando → atualização`) enquanto `game_over == 0`, exibe o radar final e seleciona a mensagem de encerramento via tabela `end_messages`, finalizando com `syscall 10`.
2. **Endereçamento de Matriz (`get_aircraft_address`):** Calcula o endereço base de qualquer voo `idx` (`0..3`) na matriz `fleet_matrix` usando deslocamentos de bits: `fleet_matrix + (idx << 4) + (idx << 2) = fleet_matrix + idx * 20`.
3. **Entrada Segura (`read_validated_integer`):** Lê texto via `syscall 8` em `input_buffer` (sem usar `syscall 5`), ignora espaços, rejeita entradas vazias ou não numéricas, converte ASCII para inteiro e valida o intervalo `[$a0, $a1]`.
4. **Renderização ASCII (`print_radar_and_table`):** Imprime cabeçalho do turno, varre a grade 2D `(4000..1000 ft × 00..07 NM)` cruzando com `fleet_matrix` (exibindo `[k ]`, `[k@]`, `[k*]`, `[==]`, `[kX]` ou `[XX]`) e imprime a tabela dos 4 voos usando a lookup table `state_names`.
5. **Comandos do Controlador (`read_and_execute_command`):** Lê a ação principal (`1-4` voo, `5` avançar todos, `0` sair) e executa o comando escolhido (`1-Descer`, `2-Órbita`, `3-Pouso`, `4-Arremeter [Dist<=4]`, `0-Voltar`), bloqueando ações inválidas sem gastar turno.
6. **Física do Turno (`update_simulation_turn`):** Atualiza combustível (`-1`), avança `-1 NM` fora de órbita, resolve pouso ou acidente em `00 NM`, detecta pane seca (`FUEL == 0`), verifica pares ativos `(0 <= i < j < 4)` para `TCAS!` (`|ΔDist| == 1`) e colisão (`|ΔDist| == 0`), e checa vitória (4 pousos) ou limite de 20 turnos.

---

## 3. Estruturas de Dados (Segmento `.data` a partir de `0x10010000`)

| Rótulo | Tamanho | Estrutura | Descrição |
| :--- | :---: | :--- | :--- |
| `fleet_matrix` | `80 B` | `4 × 5` words (`20 B/voo`) | `+0: ID`, `+4: ALT (1000..4000)`, `+8: DIST (0..7)`, `+12: FUEL`, `+16: STATE (0=APROX, 1=ORBITA, 2=AUTORIZADO, 3=POUSOU, 4=ACIDENTE)`. Base `0x10010000`. |
| `state_names` / `end_messages` | `36 B` | `5` + `4` ponteiros (`.word`) | Tabelas de consulta de strings para estados da tabela e mensagens de fim de jogo. |
| Variáveis globais | `16 B` | `4` words | `turn_number` (`1..20`), `landed_count` (`0..4`), `runway_owner` (`0..4`), `game_over` (`0..4`). |
| `input_buffer` | `64 B` | Buffer ASCII (`.space 64`) | Armazena a linha lida por `syscall 8` em `read_validated_integer`. |
| `state_symbols` | `5 B` | Vetor de bytes (`.byte`) | Símbolos `' '`, `'@'`, `'*'`, `' '`, `'X'` desenhados no radar conforme `STATE`. |

---

## 4. Procedimentos, Convenções e Uso da Pilha (`$sp`)

| Procedimento | Linhas | Parâmetros / Retorno | Uso de `$sp` e Alteração de Estado |
| :--- | :---: | :--- | :--- |
| `main` | 79–105 | — | Orquestra o fluxo principal e encerra via `syscall 10`. |
| `get_aircraft_address` | 112–118 | `$a0=idx` → `$v0=addr` | Folha (sem pilha); retorna endereço em `fleet_matrix`. |
| `read_validated_integer` | 126–170 | `$a0=min, $a1=max` → `$v0, $v1` | Preserva `$s0..$s1` (`8 B`); grava em `input_buffer`. |
| `print_radar_and_table` | 177–345 | — | Preserva `$ra, $s0..$s4` (`24 B`); somente leitura do estado. |
| `read_and_execute_command` | 353–483 | `$v0=1` (turno) ou `0` (sair) | Preserva `$ra, $s0..$s1` (`12 B`); altera `fleet_matrix`, `runway_owner` e `game_over`. |
| `update_simulation_turn` | 490–646 | — | Preserva `$ra, $s0..$s3` (`20 B`); altera `fleet_matrix`, `runway_owner`, `landed_count`, `turn_number` e `game_over`. |

---

## 5. Contagem de Instruções Úteis MIPS e Localização dos Requisitos
Pelo critério do enunciado (1 instrução por linha de origem em `.text`, contando pseudoinstruções como 1 e excluindo linhas vazias, comentários, rótulos isolados, diretivas e `.data`), [src/atc_mips.asm](file:///home/BRENO/Documents/Unifesp/aoc/aoc-final/src/atc_mips.asm) possui **425 instruções úteis** (mínimo exigido: `100`):
- `main`: `21` | `get_aircraft_address`: `6` | `read_validated_integer`: `36` | `print_radar_and_table`: `141` | `read_and_execute_command`: `103` | `update_simulation_turn`: `118`.

**Onde cada requisito aparece no código:**
- **Matriz em memória:** `fleet_matrix` (`L13–L17`), indexada em `get_aircraft_address` (`L112–L118`).
- **Decisões e repetições reais:** laço principal (`L84–L91`), leitura caractere-a-caractere (`L141–L154`), grade 2D do radar (`L211–L285`), atualização da frota (`L502–L562`) e pares `(i < j)` de separação (`L565–L617`).
- **Procedimentos, parâmetros e pilha:** 6 procedimentos usando `$a0..$a1`, `$v0..$v1`, `$s0..$s4` e `$ra` salvos/restaurados em `$sp`.
- **Entradas inválidas e encerramento:** validação via `syscall 8` (`L126–L170`), checagens em `read_and_execute_command` (`L361–L470`) e saída com `syscall 10` (`L104–L105`).

---

## 6. Contribuições e Evolução do Projeto
- **Contribuições:** Breno — especificação, implementação em Assembly MIPS32, validação no MARS CLI e documentação *(atualizar se houver demais integrantes)*.
- **Evolução:** Após protótipos maiores com múltiplas fases e mais de 2.000 linhas, o código foi refatorado para esta versão enxuta (646 linhas / 425 instruções), preservando todos os requisitos técnicos e a lógica completa de radar, pouso, órbita, arremetida, pane seca, `TCAS!` e colisão com nomes explícitos e clareza para explicação linha a linha.
