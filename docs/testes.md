# Casos de Teste Reproduzíveis — ATC-MIPS

Todos os testes abaixo são **100% determinísticos e reproduzíveis**, pois cada cenário (`1..3`) carrega em `fleet_matrix` um conjunto fixo de dados via `init_fleet`. Todos os comandos foram executados no simulador **MARS 4.6U** via linha de comando a partir da raiz do repositório.

---

## Verificação Prévia de Montagem Limpa
- **Comando:**
  ```bash
  java -jar /home/BRENO/Documents/Unifesp/aoc/Mars-Linux a ae1 nc src/atc_mips.asm
  ```
- **Resultado observado:** Código de saída `0`, sem erros ou avisos de montagem.

---

## Caso 1 — Uso Normal (Vitória com Atalho `7` e Rank S nos Cenários 1 e 2)

### Subcaso 1A — Cenário 1 (`Operacao Padrao`)
- **Objetivo:** Validar briefing inicial, seleção de cenário (`1`), pouso das 6 aeronaves, uso do atalho direto `7` (*Avançar turno mantendo todos no curso*) no último turno, ativação das ondas e cálculo da pontuação/ranking.
- **Comando de execução:**
  ```bash
  printf "1\n1\n4\n2\n1\n2\n4\n3\n1\n3\n1\n3\n4\n6\n1\n5\n1\n5\n3\n6\n4\n4\n1\n5\n1\n5\n4\n4\n1\n4\n1\n4\n4\n7\n" | java -jar /home/BRENO/Documents/Unifesp/aoc/Mars-Linux nc src/atc_mips.asm
  ```
- **Resultado esperado e observado no MARS:**
  - `MISSAO CONCLUIDA: Todas as 6 aeronaves pousaram com seguranca!`
  - `Cenario executado : Operacao Padrao`
  - `Turnos executados : 17` | `Comandos emitidos : 17` | `Pousos concluidos : 6`
  - `Alertas TCAS      : 0` | `Acidentes         : 0`
  - `Pontuacao final   : 770 pts`
  - `Avaliacao (Rank)  : RANK S - Controlador Chefe Exemplar`

### Subcaso 1B — Cenário 2 (`Hora do Rush`, 5 voos ativos + arremetida tática)
- **Comando de execução:**
  ```bash
  printf "2\n1\n4\n2\n1\n2\n4\n3\n1\n3\n4\n4\n1\n4\n1\n4\n4\n5\n5\n5\n1\n5\n1\n5\n1\n5\n4\n6\n4\n" | java -jar /home/BRENO/Documents/Unifesp/aoc/Mars-Linux nc src/atc_mips.asm
  ```
- **Resultado observado no MARS:**
  - `MISSAO CONCLUIDA: Todas as 6 aeronaves pousaram com seguranca!`
  - `Cenario executado : Hora do Rush` | `Turnos executados : 14` | `Pousos concluidos : 6`
  - `Alertas TCAS      : 1` | `Acidentes         : 0` | `Pontuacao final   : 870 pts` (`RANK S`)
- **Justificativa:** Comprova o sequenciamento completo com entrada imediata de 5 aeronaves, execução da arremetida manual (`5` em `VO-505`, `-15 pts`) e pouso de todas as 6 aeronaves.

---

## Caso 2 — Entradas Inválidas, Consulta ao Manual e Recusa de Pouso Inválido

- **Objetivo:** Comprovar que `read_safe_int` (`syscall 8`) não trava com entradas vazias ou texto, que o manual (`4` no menu inicial e `8` durante o turno) exibe as regras sem gastar turno, e que todas as pré-condições de pouso e pista reservada são bloqueadas corretamente.
- **Comando de execução:**
  ```bash
  printf "1\n\nabc\n-2\n9\n5\n8\n3\nxyz\n4\n1\n3\n1\n3\n4\n0\n1\n1\n1\n4\n3\n4\n0\n0\n" | java -jar /home/BRENO/Documents/Unifesp/aoc/Mars-Linux nc src/atc_mips.asm
  ```
- **Resultado esperado e observado no MARS:**
  - Entradas `""`, `"abc"`, `"-2"`, `"9"` e `"xyz"` exibiram `Entrada invalida! Digite apenas um numero inteiro dentro da faixa.` sem travar o simulador.
  - Slot `5` no Turno 1 exibiu `Erro: Esta aeronave ainda aguarda entrada no setor.`.
  - Opção `8` exibiu o `MANUAL COMPLETO DE OPERACAO` e retornou ao `[5] PAINEL DE COMANDO DA TORRE` no mesmo Turno 1.
  - Tentativas inválidas de pouso exibiram, respectivamente: `Pouso negado: altitude deve ser 1000 ft.`, `Pouso negado: distancia maxima para autorizacao e 3 NM.` e `Pouso negado: pista ja reservada por outra aeronave.`.
  - Encerramento limpo por `0`: `Turnos executados : 5`, `Comandos emitidos : 4`, `Alertas TCAS : 3`, `Acidentes : 0`, `Pontuacao final : -155 pts`, `Avaliacao (Rank) : INCOMPLETO - Operacao nao concluida`.
- **Justificativa:** Valida o analisador léxico em `syscall 8`, a consulta não destrutiva do manual e todas as travas operacionais da pista.

---

## Caso 3 — Situações Limite (Colisão Aérea, Pane Seca e Emergência MAYDAY)

### Subcaso 3A — Violação de Separação (`TCAS!`) e Colisão Aérea
- **Comando de execução:**
  ```bash
  printf "1\n3\n1\n2\n3\n" | java -jar /home/BRENO/Documents/Unifesp/aoc/Mars-Linux nc src/atc_mips.asm
  ```
- **Resultado observado no MARS:**
  - No Turno 2, `VO-101` sofre `[ARREMETIDA AUTO]` ao cruzar `00 NM` sem autorização e colide com `VO-202` em órbita a `2000 ft, 3 NM`:
    - `[ACIDENTE - COLISAO] Colisao aerea entre VO-101 e VO-202! (-300 pts)`
    - `[ALERTA TCAS!] Separacao minima violada entre VO-101 e VO-303! (-25 pts)`
  - Relatório final: `Turnos executados : 2`, `Alertas TCAS : 1`, `Acidentes : 2`, `Pontuacao final : -365 pts`, `REPROVADO - Ocorrencia de acidente critico`.

### Subcaso 3B — Pane Seca (Combustível Zerado) usando Atalho `7`
- **Comando de execução:**
  ```bash
  printf "1\n2\n3\n7\n7\n7\n7\n" | java -jar /home/BRENO/Documents/Unifesp/aoc/Mars-Linux nc src/atc_mips.asm
  ```
- **Resultado observado no MARS:**
  - `VO-202` entra em `ORBITA` no Turno 1 (`Comb = 5`), declara `MAYDAY` no Turno 2 (`Comb = 3`) e zera o combustível no Turno 5 (`[ACIDENTE - PANE SECA] VO-202 esgotou o combustivel! (-300 pts)`), somando `-40` da arremetida automática do `VO-101` e `3` alertas TCAS (`-75`), encerrando com `Pontuacao final : -455 pts` e `REPROVADO`.

### Subcaso 3C — Cenário 3 (`Emergencia de Combustivel / MAYDAY`)
- **Comando de execução:**
  ```bash
  printf "3\n1\n4\n2\n1\n2\n4\n3\n1\n3\n4\n4\n1\n4\n1\n4\n4\n5\n1\n5\n1\n5\n4\n6\n1\n6\n1\n6\n4\n7\n" | java -jar /home/BRENO/Documents/Unifesp/aoc/Mars-Linux nc src/atc_mips.asm
  ```
- **Resultado observado no MARS:**
  - `VO-101` e `VO-202` iniciam em `MAYDAY` (`Comb = 3`) e são salvos nos turnos 2 e 3 (`VO-202` toca a pista com `Comb = 0`).
  - Relatório final: `MISSAO CONCLUIDA`, `Turnos executados : 14`, `Pousos concluidos : 6`, `Alertas TCAS : 0`, `Acidentes : 0`, `Pontuacao final : 740 pts` (`RANK A - Controlador Senior`).
