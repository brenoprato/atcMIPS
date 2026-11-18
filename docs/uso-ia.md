# Registro de Uso de Inteligência Artificial e Fontes — ATC-MIPS

## 1. Ferramentas Utilizadas e Finalidade
Durante o desenvolvimento do **ATC-MIPS**, foram utilizadas ferramentas de IA generativa (assistente de programação em linha de comando) para:
- Estruturar a especificação do sistema em formato iterativo (*spec-driven*) e organizar a interface 100% em **Terminal ASCII** dividida em 5 seções.
- Projetar a leitura segura de inteiros via `syscall 8` (`read_string`), sem utilizar `syscall 5` (`read_int`), e a arquitetura modular de 14 procedimentos em MIPS32.
- Automatizar a bateria de testes nos 3 cenários determinísticos via MARS CLI e validar a integridade da memória.

---

## 2. Exemplo Relevante de Uso, Adaptações e Correções

### Sugestão Inicial da IA e Evoluções Aplicadas pelo Grupo
1. **Leitura segura (`read_safe_int`) e comportamento do MARS CLI:**
   - A IA propôs validar inteiros caractere a caractere sobre um buffer de 64 bytes lido via `syscall 8`.
   - **Verificação e adaptação:** Ao inspecionar o bytecode de `mars.mips.instructions.syscalls.SyscallReadString` e `mars.util.SystemIO` no próprio `Mars-Linux` com `javap`, verificou-se que linhas vazias produzem `"\n\0"` e `EOF` em pipe faz `BufferedReader.readLine()` retornar `null` (gerando `NullPointerException` dentro do MARS). O parser em `read_safe_int` passou a rejeitar `\n` isolado de forma segura (`$v1 = 0`) e os roteiros de teste foram desenhados para encerrar naturalmente ou com `0`.
2. **Foco em Terminal ASCII, Usabilidade e Correção de Bloqueio de Turno:**
   - Na segunda iteração do projeto, removeu-se o suporte gráfico em `0x10010000` para concentrar toda a clareza na tela do console ASCII, adicionando briefing explicativo na abertura, manual completo sob demanda (opções `4` e `8`), atalho direto `7` (*Avançar turno mantendo todos no curso*), 3 cenários determinísticos e sistema de pontuação/ranking.
   - Durante os testes no MARS CLI, identificou-se que o Cenário 2 (`Hora do Rush`) exigia ajuste fino de distâncias iniciais de `VO-404`, `VO-505` e `VO-606` para que o jogador conseguisse resolver os conflitos sem colidir com a onda do Turno 4, e ajustou-se o limiar de `RANK S` para `>= 750 pts` para refletir a pontuação máxima alcançável no Cenário 1 (`770 pts`).

---

## 3. Verificação Concreta: Rastreamento Manual × Execução no MARS

Para comprovar a correção da aritmética de ponteiros em `fleet_matrix` e da detecção de colisões/`TCAS!`, comparou-se o rastreamento manual dos registradores com o **Subcaso 3A** executado no MARS.

### Trecho Verificado: `get_aircraft_addr` e `check_separation_and_collisions`
Em [src/atc_mips.asm](file:///home/BRENO/Documents/Unifesp/aoc/aoc-final/src/atc_mips.asm):
- `fleet_matrix` é o primeiro rótulo de `.data`, iniciando exatamente em **`0x10010000`** (confirmado via `dump 0x10010000-0x1001001c` no MARS: `0x10010000 = 0x00000065` = `101`, `0x10010018 = 0x000000ca` = `202`).
- `get_aircraft_addr` recebe `k` (`0..5`) em `$a0`:
  ```mips
  sll $t0, $a0, 1         # $t0 = 2 * k
  add $t0, $t0, $a0       # $t0 = 3 * k
  sll $t0, $t0, 3         # $t0 = 24 * k
  la  $v0, fleet_matrix
  add $v0, $v0, $t0       # $v0 = 0x10010000 + 24 * k
  ```
  - Slot 1 (`i = 0`, `VO-101`): `$v0 = 0x10010000`
  - Slot 2 (`j = 1`, `VO-202`): `$v0 = 0x10010018`
  - Slot 3 (`j = 2`, `VO-303`): `$v0 = 0x10010030`

### Rastreamento Manual no Turno 2 do Subcaso 3A (`1`, `3,1` no T1; `2,3` no T2)
1. **Estado imediatamente antes de `check_separation_and_collisions` no Turno 2:**
   - `VO-101` (`0x10010000`): cruzou `00 NM` sem autorização → arremetida automática grava `ALT = 2000`, `DIST = 3`, `FUEL = 4`, `STATE = 1`, e `add_score(-40)` ajusta `current_score` para `-40`.
   - `VO-202` (`0x10010018`): em `ORBITA` (`STATE = 2`) → mantém `ALT = 2000`, `DIST = 3`, `FUEL = 3`.
   - `VO-303` (`0x10010030`): desceu no Turno 1 para `2000 ft` → `ALT = 2000`, `DIST = 4`, `FUEL = 7`, `STATE = 1`.
2. **Execução de `check_separation_and_collisions` (`i = 0`, `$s2 = 0x10010000`):**
   - Par `(i=0, j=1)` com `$s3 = 0x10010018`:
     - `4($s2) = 2000 == 4($s3) = 2000`; `8($s2) = 3`, `8($s3) = 3` → `sub $t5, $t3, $t4` resulta `$t5 = 0` → desvia para `csc_collision`: grava `STATE = 6` em ambos, soma `2` em `incidents_count`, chama `add_score(-300)` (`score = -340`) e define `game_over_flag = 2`.
   - Par `(i=0, j=2)` com `$s3 = 0x10010030`:
     - O laço ainda avalia `(0, 2)`: `ALT = 2000 == 2000` e `|3 - 4| = 1` → desvia para `csc_tcas`, grava `ALERT = 2` (`TCAS!`), incrementa `tcas_warnings = 1` e chama `add_score(-25)` (`score = -365`).
3. **Comparação com o output real do MARS:**
   - Saída observada no console: `[ACIDENTE - COLISAO] Colisao aerea entre VO-101 e VO-202! (-300 pts)`, `[ALERTA TCAS!] Separacao minima violada entre VO-101 e VO-303! (-25 pts)`, `Alertas TCAS : 1`, `Acidentes : 2`, `Pontuacao final : -365 pts`, `REPROVADO - Ocorrencia de acidente critico`.
   - O resultado da execução real coincidiu exatamente com o rastreamento manual.

---

## 4. Fontes Externas
- Documentação de syscalls do simulador MARS 4.5+ e inspeção direta das classes `SyscallReadString`, `SyscallMidiOut` e `SystemIO` em `Mars-Linux`. Todo o código em [src/atc_mips.asm](file:///home/BRENO/Documents/Unifesp/aoc/aoc-final/src/atc_mips.asm) foi redigido especificamente para este projeto.
