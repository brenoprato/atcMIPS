# Casos de Teste Reproduzíveis — ATC-MIPS

As Fases 1, 2 e 3 são **100% determinísticas e reproduzíveis**, permitindo repetir exatamente qualquer sequência de teste no **MARS 4.6U** via linha de comando. Já a Fase 4 demonstra geração procedural dinâmica (`syscall 30/40/42`).

---

## Verificação Prévia de Montagem Limpa
```bash
java -jar /home/BRENO/Documents/Unifesp/aoc/Mars-Linux a ae1 nc src/atc_mips.asm
```
- **Resultado observado:** Código de saída `0`, sem erros ou avisos.

---

## Caso 1 — Uso Normal (Vitória nas 3 Fases Fixas e Modo Aleatório)

### Subcaso 1A — Fase 1: Operação Tática (Média — uso de órbita durante taxiamento)
- **Comando:**
  ```bash
  printf "1\n1\n4\n2\n3\n2\n1\n2\n4\n3\n1\n3\n1\n3\n4\n5\n1\n6\n3\n5\n4\n6\n1\n4\n1\n7\n6\n4\n4\n1\n4\n1\n7\n4\n4\n7\n" | java -jar /home/BRENO/Documents/Unifesp/aoc/Mars-Linux nc src/atc_mips.asm
  ```
- **Resultado esperado e observado:** `MISSAO CONCLUIDA: Todas as 6 aeronaves pousaram com seguranca!`, `Turnos executados : 18`, `Pousos concluidos : 6`, `Alertas TCAS : 3`, `Acidentes : 0`, `Pontuacao final : 665 pts`, `RANK A - Controlador Senior`.

### Subcaso 1B — Fase 2: Hora do Rush (Difícil — 5 voos no T1 e arremetidas táticas)
- **Comando:**
  ```bash
  printf "2\n1\n4\n2\n1\n2\n3\n2\n4\n3\n1\n3\n3\n3\n4\n4\n5\n5\n5\n6\n1\n6\n1\n6\n4\n5\n1\n4\n1\n4\n1\n4\n4\n5\n5\n5\n1\n5\n1\n5\n1\n7\n7\n5\n4\n7\n7\n" | java -jar /home/BRENO/Documents/Unifesp/aoc/Mars-Linux nc src/atc_mips.asm
  ```
- **Resultado observado:** `MISSAO CONCLUIDA: Todas as 6 aeronaves pousaram com seguranca!`, `Turnos executados : 25`, `Pousos concluidos : 6`, `Alertas TCAS : 1`, `Acidentes : 0`, `Pontuacao final : 680 pts`, `RANK A - Controlador Senior`.

### Subcaso 1C — Fase 3: Tempestade MAYDAY (Extrema — pousos sincronizados com combustível 0..1)
- **Comando:**
  ```bash
  printf "3\n1\n4\n2\n1\n2\n3\n2\n4\n3\n1\n3\n4\n4\n1\n4\n1\n4\n4\n5\n1\n5\n4\n6\n1\n6\n3\n6\n4\n7\n" | java -jar /home/BRENO/Documents/Unifesp/aoc/Mars-Linux nc src/atc_mips.asm
  ```
- **Resultado observado:** `MISSAO CONCLUIDA`, `Turnos executados : 15`, `Pousos concluidos : 6`, `Alertas TCAS : 0`, `Acidentes : 0`, `Pontuacao final : 640 pts` (`RANK B`), com `VO-202` e `VO-606` pousando com `Comb = 0`.

### Subcaso 1D — Fase 4: Modo Aleatório Dinâmico (`syscall 30/40/42`)
- **Comando (duas execuções independentes):**
  ```bash
  printf "4\n0\n" | java -jar /home/BRENO/Documents/Unifesp/aoc/Mars-Linux nc src/atc_mips.asm
  ```
- **Resultado observado:** Cada execução gerou posições e altitudes distintas sem sobreposição nem alertas `TCAS!` iniciais no Turno 1 (ex.: Execução 1 gerou `VO-101` em `1000 ft, 2 NM`, `VO-202` em `4000 ft, 4 NM`; Execução 2 gerou `VO-101` em `2000 ft, 3 NM`, `VO-404` em `1000 ft, 7 NM, ORBITA`).

---

## Caso 2 — Entradas Inválidas, Taxiamento, Arremetida Negada e Recusas de Pouso

### Subcaso 2A — Bloqueio de Pouso durante Taxiamento (`OCUPADA(TAXI)`) e Arremetida Longe da Pista (`Dist > 4 NM`)
- **Comandos:**
  ```bash
  # Testa Arremetida negada em Dist=8 NM (VO-303) e saida limpa
  printf "1\n3\n5\n0\n0\n" | java -jar /home/BRENO/Documents/Unifesp/aoc/Mars-Linux nc src/atc_mips.asm
  ```
- **Resultado observado:** `Arremetida negada: manobra so permitida na aproximacao final (Dist <= 4 NM).` seguido de encerramento limpo.
- **Teste de Taxiamento + Entradas Inválidas:**
  ```bash
  printf "1\n\nabc\n-2\n9\n5\n8\n1\n4\n2\n1\n2\n4\n3\n0\n0\n" | java -jar /home/BRENO/Documents/Unifesp/aoc/Mars-Linux nc src/atc_mips.asm
  ```
- **Resultado observado:** Entradas `""`, `"abc"`, `"-2"`, `"9"` rejeitadas por `read_safe_int`; opção `8` exibiu o manual sem gastar turno; no Turno 3 (após pouso do `VO-101` no Turno 2), o cabeçalho exibiu `Pista: OCUPADA(TAXI)`, o radar mostrou `[##]` em `00 NM` e o comando `2 -> 4` imprimiu `Pouso negado: pista ocupada por aeronave em taxiamento (aguarde 1 turno).`.

---

## Caso 3 — Situações Limite (Violação do Limite `00 NM` e Acidentes)

### Subcaso 3A — Invasão de Pista no Limite `00 NM` (`ALT == 1000 ft` sem autorização)
- **Comando:**
  ```bash
  printf "1\n1\n4\n2\n1\n2\n4\n3\n5\n6\n0\n" | java -jar /home/BRENO/Documents/Unifesp/aoc/Mars-Linux nc src/atc_mips.asm
  ```
- **Resultado observado:** Após `VO-202` ter o pouso negado no Turno 3 por taxiamento (`OCUPADA(TAXI)`) e seguir sem entrar em órbita (`6`), ao atingir `00 NM` o simulador encerrou com `[ACIDENTE - INVASAO DE PISTA] VO-202 atingiu 00 NM sem autorizacao de pouso! (-300 pts)`, `Pontuacao final : -170 pts`, `REPROVADO - Ocorrencia de acidente critico`.

### Subcaso 3B — Violação de Limite `00 NM` Acima da Rampa (`ALT > 1000 ft` sem arremeter)
- **Comando:**
  ```bash
  printf "1\n1\n4\n2\n3\n2\n4\n3\n5\n2\n1\n" | java -jar /home/BRENO/Documents/Unifesp/aoc/Mars-Linux nc src/atc_mips.asm
  ```
- **Resultado observado:** `VO-202` prosseguiu a `2000 ft` até cruzar `00 NM`, encerrando imediatamente com `[ACIDENTE - VIOLACAO DE LIMITE] VO-202 cruzou 00 NM acima da rampa sem arremeter! (-300 pts)`, `Pontuacao final : -170 pts`, `REPROVADO - Ocorrencia de acidente critico`.
