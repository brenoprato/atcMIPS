# Casos de Teste Reproduzíveis — ATC-MIPS

Todos os casos abaixo são **100% determinísticos e reproduzíveis** no **MARS 4.6U** via linha de comando (`Mars-Linux`), cobrindo uso normal, entradas inválidas e todas as situações limite.

---

## Verificação Prévia de Montagem Limpa
```bash
java -jar /home/BRENO/Documents/Unifesp/aoc/Mars-Linux a ae1 nc src/atc_mips.asm
```
- **Resultado esperado e observado:** Código de saída `0`, sem erros ou avisos de montagem.

---

## Caso 1 — Uso Normal (Vitória com 4/4 Pousos)
- **Objetivo:** Sequenciar e pousar todas as 4 aeronaves (`VO-101` a `VO-404`) sem colisões nem pane seca, usando descida de altitude, autorização de pouso e avanço de turno.
- **Comando:**
  ```bash
  printf "1\n3\n2\n1\n2\n3\n3\n1\n3\n1\n3\n3\n4\n1\n4\n1\n4\n1\n4\n3\n5\n5\n" | java -jar /home/BRENO/Documents/Unifesp/aoc/Mars-Linux nc src/atc_mips.asm
  ```
- **Resultado esperado e observado:**
  - `VO-101`, `VO-202`, `VO-303` e `VO-404` exibem `[POUSO] Voo pousou com seguranca!`.
  - No Turno `12/20`, `Pousos: 4/4`, tabela lista os 4 voos como `POUSOU` (combustível restante `3`, `2`, `3` e `1`) e o simulador encerra com:
    `=== VITORIA: Todos os 4 voos pousaram! ===`

---

## Caso 2 — Entradas Inválidas, Comandos Negados e Saída Limpa
- **Objetivo:** Verificar rejeição segura de linha vazia, texto não numérico e opção fora da faixa (sem travar o MARS via `syscall 5`), além de bloqueio de regras de voo e encerramento limpo (`0`).
- **Comando:**
  ```bash
  printf "\nabc\n9\n3\n3\n4\n0\n1\n1\n0\n0\n" | java -jar /home/BRENO/Documents/Unifesp/aoc/Mars-Linux nc src/atc_mips.asm
  ```
- **Sequência testada e resultado observado:**
  - `""`, `"abc"` e `"9"` → rejeitados com `Entrada invalida!` sem avançar turno nem gerar exceção.
  - `3 -> 3` (`VO-303` em `3000 ft, 6 NM`) → `Pouso negado (requer Alt=1000, Dist<=3 e Pista livre).`
  - `3 -> 4` (`VO-303` em `6 NM > 4 NM`) → `Arremetida negada (requer Dist<=4 NM).`
  - `0` → retorna ao menu principal sem gastar turno.
  - `1 -> 1` (`VO-101` já em `1000 ft`) → `Negado: ja esta em 1000 ft.`
  - `0 -> 0` → encerra limpo com `=== FIM: Encerrado pelo controlador. ===` (`syscall 10`).

---

## Caso 3 — Situações Limite (Acidentes, TCAS! e Arremetida)

### Subcaso 3A — Limite `00 NM` sem Autorização de Pouso
- **Comando:**
  ```bash
  printf "5\n5\n" | java -jar /home/BRENO/Documents/Unifesp/aoc/Mars-Linux nc src/atc_mips.asm
  ```
- **Resultado observado:** No Turno 2, `VO-101` cruza `00 NM` em estado `APROX`, exibindo `[ACIDENTE] Limite 00 NM sem autorizacao! VO-101`, `[1X]` na célula `(1000ft, 00NM)` do radar final e `=== FIM: Operacao encerrada por acidente! ===`.

### Subcaso 3B — Pane Seca (`Comb == 0`)
- **Comando:**
  ```bash
  printf "1\n2\n2\n2\n5\n5\n5\n" | java -jar /home/BRENO/Documents/Unifesp/aoc/Mars-Linux nc src/atc_mips.asm
  ```
- **Resultado observado:** Com `VO-101` e `VO-202` em órbita, após 5 turnos o combustível do `VO-101` chega a `0`, exibindo `[ACIDENTE] Pane seca! VO-101`, `[1X]` na célula `(1000ft, 02NM)` e `=== FIM: Operacao encerrada por acidente! ===`.

### Subcaso 3C — Alerta `TCAS!` e Colisão Aérea na Mesma Célula
- **Comando:**
  ```bash
  printf "2\n1\n1\n2\n5\n" | java -jar /home/BRENO/Documents/Unifesp/aoc/Mars-Linux nc src/atc_mips.asm
  ```
- **Resultado observado:**
  - Fim do Turno 2: `VO-101` em `(1000ft, 1NM)` e `VO-202` em `(1000ft, 2NM)` disparam `[TCAS!] Proximidade perigosa na mesma altitude!`.
  - Fim do Turno 3: `VO-202` avança para `(1000ft, 1NM)` colidindo com `VO-101`, exibindo `[ACIDENTE] Colisao aerea na mesma celula!`, marcador `[XX]` em `(1000ft, 01NM)` no radar final e `=== FIM: Operacao encerrada por acidente! ===`.

### Subcaso 3D — Arremetida Tática (`Dist <= 4 NM`) e Verificação de Memória
- **Comando:**
  ```bash
  printf "1\n4\n0\n" | java -jar /home/BRENO/Documents/Unifesp/aoc/Mars-Linux nc dump 0x10010000-0x10010050 HexText /dev/stdout src/atc_mips.asm
  ```
- **Resultado observado:** `VO-101` sobe de `1000 ft` para `2000 ft` (`0x000007d0`), vai para `6 NM` (`0x00000006`) e consome `1` de combustível (`5 -> 4`, `0x00000004`), confirmado tanto na tabela ASCII quanto no dump hexadecimal de `fleet_matrix` em `0x10010000`.
