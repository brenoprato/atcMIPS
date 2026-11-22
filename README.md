# ATC-MIPS — Controle de Tráfego Aéreo / Radar de Aproximação de Pista

Simulador e jogo estratégico por turnos em **Terminal ASCII**, desenvolvido em **Assembly MIPS32** para o simulador **MARS 4.5+** (testado no **MARS 4.6U**), como projeto prático da disciplina de **Arquitetura e Organização de Computadores** (ICT-UNIFESP).

O usuário atua como controlador de voo sequenciando **4 aeronaves** (`VO-101` a `VO-404`) até uma pista única em `00 NM` (`1000 ft`), administrando descida de altitude, espera em órbita, autorização de pouso, arremetida tática, consumo de combustível e separação mínima (`TCAS!`/colisão).

---

## Integrantes

- **Breno** *(adicionar eventuais demais integrantes do grupo, RA e funções antes da entrega final)*

---

## Organização do Repositório

| Caminho | Descrição |
| :--- | :--- |
| [src/atc_mips.asm](file:///home/BRENO/Documents/Unifesp/aoc/aoc-final/src/atc_mips.asm) | **Código-fonte principal** (646 linhas, 425 instruções úteis MIPS, 6 procedimentos com nomes explícitos e comentários breves). |
| [docs/proposta-fase1.md](file:///home/BRENO/Documents/Unifesp/aoc/aoc-final/docs/proposta-fase1.md) | Proposta da Fase 1 (ideia, escopo, entradas/saídas e requisitos MIPS). |
| [docs/ficha-tecnica.md](file:///home/BRENO/Documents/Unifesp/aoc/aoc-final/docs/ficha-tecnica.md) | Ficha técnica concisa com arquitetura, matriz em memória, procedimentos, uso da pilha e contagem de instruções. |
| [docs/testes.md](file:///home/BRENO/Documents/Unifesp/aoc/aoc-final/docs/testes.md) | Casos de teste determinísticos reproduzíveis no MARS CLI (vitória, entradas inválidas e situações limite). |
| [docs/uso-ia.md](file:///home/BRENO/Documents/Unifesp/aoc/aoc-final/docs/uso-ia.md) | Registro de uso de IA e rastreamento manual comparado com o dump de memória e execução no MARS. |

---

## Versão e Configurações do MARS

- **Simulador compatível:** MARS 4.5 ou superior (validado em **MARS 4.6U** com Java).
- **Memory Configuration:** `Default` (segmento `.data` iniciado em `0x10010000`).
- **Delayed Branching:** Desativado (padrão do MARS).
- **Ferramentas externas:** Nenhuma necessária — toda a interação ocorre no console **Run I/O** (100% ASCII).

### Execução no MARS (GUI e CLI)
- **GUI:** Abra `src/atc_mips.asm`, confirme **Settings → Memory Configuration → Default**, pressione **F3** e **F5**, e interaja pelo painel **Run I/O**.
- **CLI (verificação de montagem):**
  ```bash
  java -jar /home/BRENO/Documents/Unifesp/aoc/Mars-Linux a ae1 nc src/atc_mips.asm
  ```
- **CLI (execução interativa):**
  ```bash
  java -jar /home/BRENO/Documents/Unifesp/aoc/Mars-Linux nc src/atc_mips.asm
  ```

---

## Regras, Radar e Comandos

### 1. Cenário e Objetivo
- **Objetivo:** Pousar os **4 voos** na pista (`1000 ft`, `00 NM`) em até **20 turnos**, sem colisões, invasão da pista (`00 NM` sem autorização) ou pane seca (`Comb == 0`).
- **Radar 2D ASCII:** Grade de `4` altitudes (`4000..1000 ft`) × `8` distâncias (`00..07 NM`):
  - `[k ]` Voo `k` em aproximação (`APROX`)
  - `[k@]` Voo `k` em espera (`ORBITA`)
  - `[k*]` Voo `k` com pouso autorizado (`AUTORIZADO`)
  - `[==]` Cabeceira da pista (`1000 ft, 00 NM`)
  - `[kX]` / `[XX]` Acidente individual ou colisão aérea na célula

### 2. Comandos por Turno
- **Ação principal:**
  - `1..4`: seleciona um voo ativo (`VO-101`..`VO-404`)
  - `5`: **Avançar turno** (mantém todos os voos no estado atual)
  - `0`: **Encerrar programa** com saída limpa (`syscall 10`)
- **Comandos do voo selecionado:**
  - `1` — **Descer (`-1000 ft`)**: reduz altitude até o piso de `1000 ft` (sai de `ORBITA` para `APROX`).
  - `2` — **Alternar Órbita**: congela a distância (`DIST`) do voo para aguardar a liberação da pista ou evitar colisões.
  - `3` — **Autorizar Pouso**: exige `Alt == 1000 ft`, `Dist <= 3 NM` e `Pista == 0` (livre).
  - `4` — **Arremeter**: exige `Dist <= 4 NM`; sobe `+1000 ft` (teto `4000 ft`), libera a pista e reposiciona o voo em `06 NM` após o turno.
  - `0` — **Voltar** para a seleção de voo (sem gastar turno).

### 3. Regras Críticas
- A cada turno, cada voo ativo consome `-1` de combustível e avança `-1 NM` (exceto em `ORBITA`).
- Ao chegar em `00 NM`: pousa com segurança se `AUTORIZADO` e `Alt == 1000 ft`; caso contrário, ocorre **ACIDENTE**.
- Combustível zerado (`Comb == 0`) em voo provoca **Pane Seca (ACIDENTE)**.
- Dois voos ativos na mesma altitude: distância `|DIST_i - DIST_j| == 1` gera alerta **`[TCAS!]`**; distância `== 0` gera **Colisão Aérea (ACIDENTE)**.

---

## Limitações Conhecidas

- Simulação discreta em fase única com 4 aeronaves sobre grade de `4` altitudes (`1000..4000 ft`) × `8` distâncias (`00..07 NM`).
- Em execuções via pipe (`stdin`) no MARS CLI, alcançar `EOF` enquanto o programa aguarda `syscall 8` gera `NullPointerException` interna em `SystemIO.readString()` do MARS; por isso, roteiros automatizados devem encerrar a partida ou enviar `0`.

---

## Vídeo de Demonstração

- **Link do vídeo final (até 4 minutos):** *[A inserir após gravação e publicação antes da entrega da Fase 3]*
