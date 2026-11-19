# Registro de Uso de Inteligência Artificial e Fontes — ATC-MIPS

## 1. Ferramentas Utilizadas e Finalidade
Durante o desenvolvimento do **ATC-MIPS**, foram utilizadas ferramentas de IA generativa (assistente de programação em linha de comando) para:
- Estruturar a especificação, modularizar os **17 procedimentos** em MIPS32 e desenhar o painel em **Terminal ASCII** organizado em 5 seções.
- Projetar a leitura segura via `syscall 8` (sem `syscall 5`), o gerador aleatório `init_random_fleet` via syscalls `30`, `40` e `42` do MARS e a lógica de taxiamento/limite frontal da matriz.
- Executar baterias de teste no `Mars-Linux` CLI e verificar offsets de memória.

---

## 2. Exemplo Relevante de Uso, Adaptações e Correções

### Evolução das Regras Críticas e Verificação no MARS
1. **Eliminação da "Arremetida Automática" no Limite `00 NM` e Taxiamento da Pista:**
   - Na versão inicial, quando uma aeronave cruzava `00 NM` sem autorização de pouso, ela retornava automaticamente para `3 NM` e `>= 2000 ft`.
   - **Correção aplicada após revisão de gameplay:** Essa mecânica tornava o simulador permissivo e confuso. Substituiu-se o retorno automático por **acidente crítico imediato no limite da matriz** (`INVASAO DE PISTA` ou `VIOLACAO DE LIMITE`, `-300 pts`), restringindo a arremetida ao comando manual `5` apenas quando `Dist <= 4 NM` (retornando a `08 NM`), e adicionando `runway_cooldown = 1` (1 turno de taxiamento `[##]` após cada pouso).
2. **Inspeção das Syscalls Aleatórias e de String no `Mars-Linux`:**
   - Antes de implementar `init_random_fleet`, inspecionou-se com `javap` o bytecode de `SyscallRandIntRange` (`42`), `SyscallRandSeed` (`40`) e `SyscallTime` (`30`) no executável `Mars-Linux`, confirmando que `syscall 42` recebe o stream em `$a0`, o limite exclusivo em `$a1` e grava o resultado diretamente em **`$a0`** (e não em `$v0`). Esse detalhe evitou um erro clássico de leitura de registrador errado.

---

## 3. Verificação Concreta: Rastreamento Manual × Execução no MARS

Comparou-se o rastreamento manual da lógica de **limite `00 NM` + taxiamento (`runway_cooldown`)** com o **Subcaso 3A** executado no MARS CLI.

### Trecho Verificado: `update_simulation_turn` (linhas 1951–2118 de [src/atc_mips.asm](file:///home/BRENO/Documents/Unifesp/aoc/aoc-final/src/atc_mips.asm))
1. **Turno 2 (`VO-101` pousa):**
   - `VO-101` (`0x10010000`) inicia o Turno 2 com `ALT = 1000`, `DIST = 1`, `FUEL = 4`, `STATE = 3 (AUTORIZADO)`.
   - Em `ust_move_plane`: `FUEL` vai para `3`, `DIST` vai para `0` (`bgtz $t4` não desvia).
   - `STATE == 3` e `ALT == 1000` executam o bloco de pouso: `STATE = 4`, `runway_reserved_by = 0`, `runway_cooldown = 1`, `landed_count = 1`, e `add_score(100 + 10 * 3 = +130)` leva `current_score` de `0` para `130`.
2. **Turno 3 (`OCUPADA(TAXI)` e Invasão de Pista do `VO-202`):**
   - Como `runway_cooldown == 1`, `render_ascii_radar` exibe `Pista: OCUPADA(TAXI)` e `[##]`, e `process_controller_cmd` rejeita `2 -> 4` em `pcc_rej_lnd_taxi`.
   - Ao emitir `2 -> 6` (*Manter curso*), `VO-202` (`0x10010018`, em `ALT = 1000`, `DIST = 1`, `STATE = 1`) avança em `ust_move_plane` para `DIST = 0`.
   - Como `STATE == 1` (`!= 3`), desvia para `ust_limit_crash`: grava `STATE = 6`, `ALERT = 3`, `incidents_count = 1`, `game_over_flag = 2`, `add_score(-300)` (`130 - 300 = -170`), e como `ALT == 1000` imprime `[ACIDENTE - INVASAO DE PISTA]`.
3. **Conferência com o output real do MARS:**
   - Saída observada: `Pista: OCUPADA(TAXI)`, `Pouso negado: pista ocupada por aeronave em taxiamento (aguarde 1 turno).`, `[ACIDENTE - INVASAO DE PISTA] VO-202 atingiu 00 NM sem autorizacao de pouso! (-300 pts)`, `Pontuacao final : -170 pts`, `REPROVADO - Ocorrencia de acidente critico`.
   - Comportamento observado no MARS idêntico ao rastreamento manual.

---

## 4. Fontes Externas
- Documentação de syscalls do MARS 4.5+ e inspeção via `javap` das classes `SyscallReadString`, `SyscallMidiOut`, `SyscallTime`, `SyscallRandSeed`, `SyscallRandIntRange` e `SystemIO` no binário `Mars-Linux`.
