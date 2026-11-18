# ATC-MIPS — Controle de Tráfego Aéreo / Radar de Aproximação de Pista

Simulador e jogo estratégico por turnos em **Terminal ASCII**, desenvolvido em **Assembly MIPS32** para o simulador **MARS 4.5+** (testado no **MARS 4.6U**), como projeto prático da disciplina de **Arquitetura e Organização de Computadores** (ICT-UNIFESP).

O usuário assume o papel de controlador de voo responsável por sequenciar **6 aeronaves** até uma única pista de pouso (`00 NM`), escolhendo entre **3 cenários determinísticos**, gerenciando altitudes (`1000..4000 ft`), distância, reservas de combustível, esperas em órbita, alertas de separação mínima (`TCAS!`) e emergências (`MAYDAY`), com sistema de **pontuação e classificação final**.

---

## Integrantes

- **Breno** *(adicionar eventuais demais integrantes do grupo, RA e funções antes da entrega final)*

---

## Organização do Repositório

| Caminho | Descrição |
| :--- | :--- |
| [src/atc_mips.asm](file:///home/BRENO/Documents/Unifesp/aoc/aoc-final/src/atc_mips.asm) | **Arquivo principal** com briefing inicial, manual consultável, 3 cenários, interface ASCII organizada em 5 seções, simulação de voo, pontuação e áudio MIDI. |
| [docs/proposta-fase1.md](file:///home/BRENO/Documents/Unifesp/aoc/aoc-final/docs/proposta-fase1.md) | Proposta inicial da Fase 1 (ideia, escopo, entradas/saídas e plano de desenvolvimento). |
| [docs/ficha-tecnica.md](file:///home/BRENO/Documents/Unifesp/aoc/aoc-final/docs/ficha-tecnica.md) | Ficha técnica com arquitetura, estruturas de dados, procedimentos, contagem de instruções e requisitos MIPS. |
| [docs/testes.md](file:///home/BRENO/Documents/Unifesp/aoc/aoc-final/docs/testes.md) | Casos de teste determinísticos e reproduzíveis executados no MARS CLI (cenários 1, 2 e 3, entradas inválidas e situações limite). |
| [docs/uso-ia.md](file:///home/BRENO/Documents/Unifesp/aoc/aoc-final/docs/uso-ia.md) | Registro de uso de inteligência artificial e verificação manual comparada com a execução no MARS. |

---

## Versão e Configurações do MARS

- **Simulador compatível:** MARS 4.5 ou superior (validado em **MARS 4.6U** com Java).
- **Memory Configuration:** `Default` (segmento `.data` iniciado em `0x10010000`).
- **Delayed Branching:** Desativado (padrão do MARS).
- **Ferramentas adicionais:** Nenhuma ferramenta gráfica externa é necessária — toda a visualização ocorre no painel **Run I/O** (console ASCII) com feedback sonoro discreto via **MIDI (`syscall 31`)**.

### Execução na Interface Gráfica (GUI) do MARS
1. Abra o MARS e carregue o arquivo **`src/atc_mips.asm`**.
2. Confirme em **Settings → Memory Configuration** que está selecionado **`Default`**.
3. Pressione **F3** (Assemble) e **F5** (Run).
4. Interaja pelo painel **Run I/O**.

### Execução via Linha de Comando (CLI)
Para validar apenas a montagem:
```bash
java -jar /home/BRENO/Documents/Unifesp/aoc/Mars-Linux a ae1 nc src/atc_mips.asm
```

Para executar interativamente no terminal:
```bash
java -jar /home/BRENO/Documents/Unifesp/aoc/Mars-Linux nc src/atc_mips.asm
```

---

## Como Funciona e Comandos de Interação

### 1. Abertura, Briefing e Seleção de Cenário
Ao iniciar, o simulador exibe um **Briefing Inicial** explicando o objetivo, o funcionamento do turno, os símbolos do radar e as regras de pouso. Em seguida, permite escolher:
- `1` — **Operacao Padrao** (tráfego moderado com entrada em ondas nos turnos 2 e 4).
- `2` — **Hora do Rush** (5 voos ativos já no Turno 1 com conflitos de altitude em `2000 ft` e `3000 ft`).
- `3` — **Emergencia de Combustivel** (voos iniciando já em `MAYDAY` com `Comb = 3`).
- `4` — **Ver Manual Completo, Regras e Pontuacao**.
- `0` — **Encerrar Simulador**.

### 2. Organização do Painel a Cada Turno
Cada ciclo no terminal segue 5 seções fixas e padronizadas:
- **`[1] CAIXA DE RADIO / EVENTOS DO TURNO`**: confirma a ordem dada pela torre e registra pousos, alertas `MAYDAY`, `TCAS!`, arremetidas e chegada de ondas.
- **`[2] CABECALHO DO SETOR`**: exibe Turno (`X / 25`), Cenário ativo, Pontuação (`Score`), Status da Pista (`LIVRE` ou `RESERV(VO-xxx)`), Pousos (`X/6`), Alertas TCAS e Acidentes.
- **`[3] RADAR DE APROXIMACAO 2D (ASCII)`**: grade `4000..1000 ft` × `00..10 NM` com legenda fixa logo abaixo.
- **`[4] TABELA DE TELEMETRIA DA FROTA`**: mostra `Slot | Voo | Alt(ft) | Dist(NM) | Comb | Estado | Alerta`.
- **`[5] PAINEL DE COMANDO DA TORRE`**:
  - `1..6`: seleciona um voo ativo para emitir ordem (`1-Reduzir -1000ft`, `2-Subir +1000ft`, `3-Alternar orbita`, `4-Autorizar pouso`, `5-Arremeter +1000ft/+3NM`, `6-Manter curso da aeronave`, `0-Voltar`).
  - `7`: **Avancar turno (manter todas as aeronaves no curso atual)**.
  - `8`: **Consultar Manual Completo / Regras** (a qualquer momento, sem gastar turno).
  - `0`: **Encerrar operacao**.

### 3. Regras, Pontuação e Ranking
- **Avanço e combustível:** voos ativos fora de órbita avançam `-1 NM/turno`; todos em voo consomem `1` de combustível por turno.
- **Pouso válido:** exige `ALT == 1000 ft`, `DIST <= 3 NM` e `Pista LIVRE`. Cruzar `00 NM` sem autorização gera arremetida automática (`3 NM`, `>= 2000 ft`).
- **Separação mínima:** dois voos na mesma altitude com `|DistA - DistB| == 1` disparam `TCAS!`; na mesma célula (`DistA == DistB`), ocorre colisão aérea.
- **Pontuação e Rank:** `+(100 + 10 * Comb_restante)` por pouso seguro | `-15` arremetida manual | `-25` alerta TCAS | `-40` arremetida automática | `-300` acidente. Ranks sem acidentes: **`RANK S`** (`>= 750`), **`RANK A`** (`>= 650`), **`RANK B`** (`>= 500`), **`RANK C`** (`< 500`).

---

## Limitações Conhecidas

- Simulação discreta por turnos sobre grade fixa de `4` altitudes (`1000..4000 ft`) e `11` distâncias (`00..10 NM`).
- Cenários determinísticos para garantir total reprodutibilidade dos casos de teste.
- Em execuções automatizadas via pipe (`stdin`) no MARS CLI, caso o fluxo atinja `EOF` antes do término da partida ou de um comando `0`, `SystemIO.readString()` no MARS lança `NullPointerException` por retorno nulo de `readLine()`. Scripts de teste devem sempre encerrar o jogo ou enviar `0`.

---

## Vídeo de Demonstração

- **Link do vídeo final (até 4 minutos):** *[A inserir após gravação e publicação antes da entrega da Fase 3]*
