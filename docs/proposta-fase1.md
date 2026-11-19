# Fase 1 — Proposta do Projeto: ATC-MIPS

## 1. Identificação
- **Nome do produto:** **ATC-MIPS** (*Air Traffic Control* — Controle de Tráfego Aéreo / Radar de Aproximação de Pista)
- **Disciplina:** Arquitetura e Organização de Computadores — ICT/UNIFESP (Profa. Denise Stringhini)
- **Grupo / Integrantes:** Breno *(atualizar com eventuais demais integrantes do grupo)*
- **Repositório GitHub:** *[Inserir URL do repositório após criação/push remoto]*

---

## 2. Objetivo, Público Previsto e Interação Principal
- **Objetivo:** Simular um setor de controle de aproximação aérea com pista única em **Terminal ASCII** no simulador MARS, desafiando o controlador a gerenciar 6 aeronaves em **3 fases fixas de dificuldade crescente** ou em **Modo Aleatório Dinâmico**, respeitando limites rígidos da pista (`00 NM`), tempo de taxiamento pós-pouso, consumo de combustível e separação mínima.
- **Público previsto:** Estudantes e avaliadores da disciplina de Arquitetura e Organização de Computadores interessados em simulações de sistemas críticos baseadas em estados discretos e estruturas matriciais em Assembly MIPS.
- **Interação principal:** Após um briefing inicial detalhado e seleção de fase/modo, o usuário opera a cada turno sobre um painel organizado em 5 seções (`Caixa de Rádio`, `Cabeçalho do Setor`, `Radar 2D ASCII com Legenda`, `Tabela de Telemetria` e `Painel de Comando da Torre`), podendo comandar voos ativos (`1..6`), avançar o turno mantendo todos no curso (`7`), consultar o manual (`8`) ou encerrar (`0`).

---

## 3. Entradas, Processamento e Saídas Esperadas

### Entradas
- Escolha inicial de fase/modo (`1..4`), consulta ao manual (`5`) ou encerramento (`0`).
- Opções no painel da torre (`0..8`) e comandos individuais de voo (`0..6`), lidos exclusivamente como strings via `syscall 8` (`read_safe_int`).

### Processamento
- Inicialização de `fleet_matrix` (`6 × 6 words`: `ID`, `ALT`, `DIST`, `FUEL`, `STATE`, `ALERT`) por tabela fixa (`init_fleet`) ou gerador procedural sem conflitos iniciais (`init_random_fleet` via `syscall 30/40/42`).
- Validação de regras operacionais: limites verticais (`1000..4000 ft`), autorização de pouso (`ALT=1000`, `DIST<=3`, pista livre e fora de taxiamento `runway_cooldown == 0`), arremetida tática apenas na aproximação final (`DIST <= 4 NM`, retornando a `08 NM`).
- Atualização por turno: avanço `-1 NM` fora de órbita, consumo `-1` combustível, pouso (`runway_cooldown = 1`), falha crítica ao cruzar `00 NM` sem autorização, `MAYDAY`/`PANE SECA`, verificação `O(n²)` de `TCAS!`/colisão, ondas nos Turnos 2 e 4 e cálculo de pontuação/ranking.

### Saídas
- Painel ASCII organizado em 5 seções, relatório final com ranking de desempenho (`RANK S` a `REPROVADO`) e feedback sonoro MIDI via `syscall 31`.

---

## 4. Incorporação dos Requisitos Técnicos de MIPS
- **Estrutura de dados em memória:** Matriz `fleet_matrix` (`144 B` a partir de `0x10010000`) indexada via deslocamentos em `get_aircraft_addr` e 3 tabelas de cenário.
- **Decisões e repetições reais:** Laço principal, varredura 2D do radar, laço de geração sem sobreposição no RNG, parser léxico em `read_safe_int` e verificação par-a-par de colisões.
- **Procedimentos, convenções e pilha (`$sp`):** **17 procedimentos** preservando `$ra` e `$s0..$s5` na pilha com retorno simétrico.
- **Tratamento robusto de entradas e encerramento:** Proibição de `syscall 5`; tratamento seguro de strings inválidas e saída limpa via `syscall 10`.
