# Registro de Uso de Inteligência Artificial e Fontes — ATC-MIPS

## 1. Ferramentas Utilizadas e Finalidade
Durante o desenvolvimento do **ATC-MIPS**, foi utilizada uma ferramenta de IA generativa (assistente de programação em linha de comando) para:
- Auxiliar na modelagem da matriz `fleet_matrix` (`4 × 5 words`) e na organização dos 6 procedimentos em Assembly MIPS32.
- Implementar o leitor seguro de inteiros via `syscall 8` (`read_validated_integer`), eliminando o risco de travamento do `syscall 5`.
- Refatorar o código para uma versão enxuta (646 linhas / 425 instruções úteis), com rótulos explícitos e comentários didáticos, além de automatizar testes no `Mars-Linux`.

---

## 2. Exemplo Relevante de Uso, Adaptações e Correções

### Correção 1 — Exibição de Acidentes (`[kX]` e `[XX]`) no Radar Final
- **Problema encontrado nos testes:** Na primeira versão da refatoração enxuta, `print_radar_and_table` ignorava qualquer aeronave com `STATE >= 3` (`bge $t2, 3, radar_scan_next`). Com isso, após uma colisão aérea ou pane seca (`STATE = 4`), o radar final ocultava os aviões acidentados e não exibia o marcador `[XX]` nem `[kX]`.
- **Correção aplicada:** Alterou-se o desvio em [src/atc_mips.asm](file:///home/BRENO/Documents/Unifesp/aoc/aoc-final/src/atc_mips.asm#L230-L231) para `beq $t2, 3, radar_scan_next` (ocultando apenas voos `POUSOU`), estendeu-se `state_symbols` para `.byte ' ', '@', '*', ' ', 'X'` e adicionou-se o salto `j turn_pair_next_i` após registrar colisão em `turn_air_collision`. No reteste (Subcasos 3A, 3B e 3C), `[1X]` e `[XX]` passaram a aparecer exatamente na célula do acidente.

### Correção 2 — Simplificação Arquitetural e Nomenclatura Explícita
- **Ajuste:** A versão intermediária havia crescido para mais de 2.000 linhas com siglas abreviadas nos rótulos (`m_acc`, `rr_s0`, etc.). Refatorou-se o projeto para **1 fase determinística**, **6 procedimentos** com nomes completos e tabelas de consulta (`state_names`, `end_messages`, `state_symbols`), reduzindo o código em ~73% sem perder nenhum requisito do enunciado.

---

## 3. Verificação Concreta: Rastreamento Manual × Execução no MARS

Realizou-se o rastreamento manual da **aritmética de endereços (`get_aircraft_address`)**, da **arremetida (`command_go_around`)** e da **atualização de turno (`update_simulation_turn`)** comparando com o dump hexadecimal de memória do **Subcaso 3D** (`printf "1\n4\n0\n"`).

### Rastreamento Manual (`src/atc_mips.asm`, `L112–L118`, `L447–L464` e `L500–L520`)
1. **Endereço do Slot 1 (`idx = 0`, `VO-101`):**
   - `get_aircraft_address(0)`: `(0 << 4) + (0 << 2) = 0` → `$v0 = 0x10010000`.
   - Estado inicial em `0x10010000..0x10010010`: `ID = 101 (0x65)`, `ALT = 1000 (0x3e8)`, `DIST = 2`, `FUEL = 5`, `STATE = 0 (APROX)`.
2. **Comando `4` (Arremeter) em `command_go_around`:**
   - Verifica `DIST <= 4`: `2 <= 4` (aceito).
   - `ALT = 1000 + 1000 = 2000 (0x7d0)` → gravado em `4($s1) = 0x10010004`.
   - `DIST = 7` → gravado em `8($s1) = 0x10010008`.
   - `STATE = 0` → gravado em `16($s1) = 0x10010010`.
3. **Atualização do Turno 1 em `update_simulation_turn`:**
   - `VO-101` (`0x10010000`): `FUEL: 5 -> 4 (0x4)`, `DIST: 7 -> 6 (0x6)`, `ALT = 2000 (0x7d0)`, `STATE = 0`.
   - `VO-202` (`0x10010014`, `idx = 1 → +20 B = +0x14`): `ID = 202 (0xca)`, `ALT = 2000 (0x7d0)`, `DIST: 4 -> 3 (0x3)`, `FUEL: 6 -> 5 (0x5)`, `STATE = 0`.
   - `VO-303` (`0x10010028`, `idx = 2 → +40 B = +0x28`): `ID = 303 (0x12f)`, `ALT = 3000 (0xbb8)`, `DIST: 6 -> 5 (0x5)`, `FUEL: 9 -> 8 (0x8)`, `STATE = 0`.
   - `VO-404` (`0x1001003C`, `idx = 3 → +60 B = +0x3c`): `ID = 404 (0x194)`, `ALT = 4000 (0xfa0)`, `DIST = 6 (0x6, em ORBITA)`, `FUEL: 13 -> 12 (0xc)`, `STATE = 1`.
4. **Conferência com o Dump Real do MARS (`dump 0x10010000-0x10010050`):**
   - `0x10010000`: `00000065  000007d0  00000006  00000004  00000000` (`VO-101`)
   - `0x10010014`: `000000ca  000007d0  00000003  00000005  00000000` (`VO-202`)
   - `0x10010028`: `0000012f  00000bb8  00000005  00000008  00000000` (`VO-303`)
   - `0x1001003C`: `00000194  00000fa0  00000006  0000000c  00000001` (`VO-404`)
   - **Resultado:** Os 20 words dumpados pelo MARS coincidem 100% com o rastreamento manual.

---

## 4. Fontes Externas
- Documentação oficial de syscalls e convenções MIPS do simulador **MARS 4.5+**.
- Inspeção via `javap` da classe `SystemIO` no binário `Mars-Linux` para compreender o comportamento de `syscall 8` (`read_string`) em entradas vazias e `EOF`.
