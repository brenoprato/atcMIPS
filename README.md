# ATC-MIPS — Controle de Tráfego Aéreo / Radar de Aproximação de Pista

Simulador e jogo estratégico por turnos em **Terminal ASCII**, desenvolvido em **Assembly MIPS32** para o simulador **MARS 4.5+** (testado no **MARS 4.6U**), como projeto prático da disciplina de **Arquitetura e Organização de Computadores** (ICT-UNIFESP).

O usuário atua como controlador de voo sequenciando **6 aeronaves** até uma pista única (`00 NM`), escolhendo entre **3 fases fixas desafiadoras** ou um **Modo Aleatório Dinâmico (RNG `syscall 42`)**, respeitando o tempo de taxiamento pós-pouso (`1` turno de pista ocupada), os limites rigorosos do setor (`00 NM`) e o consumo contínuo de combustível.

---

## Integrantes

- **Breno** *(adicionar eventuais demais integrantes do grupo, RA e funções antes da entrega final)*

---

## Organização do Repositório

| Caminho | Descrição |
| :--- | :--- |
| [src/atc_mips.asm](file:///home/BRENO/Documents/Unifesp/aoc/aoc-final/src/atc_mips.asm) | **Arquivo principal** com briefing inicial, manual consultável, 3 fases fixas + modo aleatório (`syscall 30/40/42`), interface ASCII em 5 seções, simulação rigorosa e áudio MIDI (`syscall 31`). |
| [docs/proposta-fase1.md](file:///home/BRENO/Documents/Unifesp/aoc/aoc-final/docs/proposta-fase1.md) | Proposta da Fase 1 (ideia, escopo, entradas/saídas e plano de desenvolvimento). |
| [docs/ficha-tecnica.md](file:///home/BRENO/Documents/Unifesp/aoc/aoc-final/docs/ficha-tecnica.md) | Ficha técnica concisa com arquitetura, estruturas de dados, procedimentos, contagem de instruções e requisitos MIPS. |
| [docs/testes.md](file:///home/BRENO/Documents/Unifesp/aoc/aoc-final/docs/testes.md) | Casos de teste determinísticos reproduzíveis no MARS CLI (Fases 1, 2 e 3, geração aleatória, entradas inválidas e violações de limite). |
| [docs/uso-ia.md](file:///home/BRENO/Documents/Unifesp/aoc/aoc-final/docs/uso-ia.md) | Registro de uso de inteligência artificial e rastreamento manual comparado com a execução no MARS. |

---

## Versão e Configurações do MARS

- **Simulador compatível:** MARS 4.5 ou superior (validado em **MARS 4.6U** com Java).
- **Memory Configuration:** `Default` (segmento `.data` iniciado em `0x10010000`).
- **Delayed Branching:** Desativado (padrão do MARS).
- **Ferramentas externas:** Nenhuma necessária — toda a operação ocorre no console **Run I/O** (ASCII), com feedback sonoro discreto via **MIDI (`syscall 31`)**.

### Execução no MARS (GUI e CLI)
- **GUI:** Abra `src/atc_mips.asm`, confirme **Settings → Memory Configuration → Default**, pressione **F3** e **F5**, e interaja pelo painel **Run I/O**.
- **CLI (montagem):**
  ```bash
  java -jar /home/BRENO/Documents/Unifesp/aoc/Mars-Linux a ae1 nc src/atc_mips.asm
  ```
- **CLI (execução interativa):**
  ```bash
  java -jar /home/BRENO/Documents/Unifesp/aoc/Mars-Linux nc src/atc_mips.asm
  ```

---

## Fases, Regras de Limite e Comandos

### 1. Seleção de Fase / Modo
Após o **Briefing Inicial** explicativo, escolha:
- `1` — **Fase 1: Operacao Tatica (Media - Fixa):** exige usar espera em órbita para respeitar o taxiamento da pista sem invadir `00 NM`.
- `2` — **Fase 2: Hora do Rush (Dificil - Fixa):** 5 voos ativos no Turno 1 com congestionamento triplo em `2000 ft`, exigindo separação, órbitas e arremetidas táticas.
- `3` — **Fase 3: Tempestade MAYDAY (Extrema - Fixa):** voos iniciando em emergência crítica de combustível, exigindo pousos sincronizados no limite (`Comb = 0..1`).
- `4` — **Fase 4: Modo Aleatorio Dinamico:** gera posições, altitudes, órbitas e combustível enxuto a cada partida usando o RNG do MARS (`syscall 30/40/42`), evitando colisões/TCAS no Turno 1.
- `5` — **Ver Manual Completo, Limites da Matriz e Pontuacao**.
- `0` — **Encerrar Simulador**.

### 2. Estrutura do Terminal a Cada Turno (5 Seções)
1. **`[1] CAIXA DE RADIO / EVENTOS DO TURNO`**: confirma ordens da torre e relata pousos, liberação de taxiamento, alertas `MAYDAY`, `TCAS!`, chegadas e acidentes.
2. **`[2] CABECALHO DO SETOR`**: Turno (`X / 25`), Modo ativo, **Score**, Status da Pista (`LIVRE`, `RESERV(VO-xxx)` ou `OCUPADA(TAXI)`), Pousos, Alertas TCAS e Acidentes.
3. **`[3] RADAR DE APROXIMACAO 2D (ASCII)`**: grade `4000..1000 ft` × `00..10 NM` com legenda fixa logo abaixo (`[==]` Pista livre, `[##]` Pista em taxiamento).
4. **`[4] TABELA DE TELEMETRIA DA FROTA`**: mostra `Slot | Voo | Alt(ft) | Dist(NM) | Comb | Estado | Alerta`.
5. **`[5] PAINEL DE COMANDO DA TORRE`**:
   - `1..6`: seleciona aeronave ativa (`1-Reduzir -1000ft`, `2-Subir +1000ft`, `3-Alternar orbita`, `4-Autorizar pouso`, `5-Arremeter [exige Dist<=4 NM]`, `6-Manter curso`, `0-Voltar`).
   - `7`: **Avancar turno (manter todas as aeronaves no curso atual)**.
   - `8`: **Consultar Manual Completo / Limites e Regras** (sem gastar turno).
   - `0`: **Encerrar operacao**.

### 3. Regras Críticas e Pontuação
- **Limite da Matriz (`00 NM`):** se uma aeronave atingir `00 NM` sem estar `AUTORIZADO` a `1000 ft`, não há retorno automático — ocorre **ACIDENTE CRÍTICO** (`INVASAO DE PISTA` ou `VIOLACAO DE LIMITE`, `-300 pts`) e fim da partida.
- **Taxiamento Pós-Pouso:** após cada pouso bem-sucedido, a pista fica **`OCUPADA(TAXI)`** (`[##]`) por **1 turno inteiro**, bloqueando novas autorizações de pouso nesse turno.
- **Arremetida Tática (`Comando 5`):** permitida somente na aproximação final (**`Dist <= 4 NM`**); sobe `+1000 ft` (teto `4000 ft`) e retorna o voo ao circuito em `08 NM` (`-15 pts`).
- **Pontuação e Rank:** `+(100 + 10 × Comb_restante)` por pouso | `-15` arremetida | `-25` `TCAS!` | `-300` acidente. Ranks sem acidentes: **`RANK S`** (`>= 750`), **`RANK A`** (`>= 650`), **`RANK B`** (`>= 500`), **`RANK C`** (`< 500`).

---

## Limitações Conhecidas

- Simulação discreta por turnos sobre grade de `4` altitudes (`1000..4000 ft`) e `11` distâncias (`00..10 NM`).
- Em execuções via pipe (`stdin`) no MARS CLI, alcançar `EOF` antes do término da partida ou de um comando `0` provoca `NullPointerException` em `SystemIO.readString()` do MARS; roteiros automatizados devem sempre encerrar a partida ou enviar `0`.

---

## Vídeo de Demonstração

- **Link do vídeo final (até 4 minutos):** *[A inserir após gravação e publicação antes da entrega da Fase 3]*
