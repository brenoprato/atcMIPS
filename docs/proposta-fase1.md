# Fase 1 — Proposta do Projeto: ATC-MIPS

## 1. Identificação
- **Nome do produto:** **ATC-MIPS** (*Air Traffic Control* — Controle de Tráfego Aéreo / Radar de Aproximação de Pista)
- **Disciplina:** Arquitetura e Organização de Computadores — ICT/UNIFESP (Profa. Denise Stringhini)
- **Grupo / Integrantes:** Breno *(atualizar com eventuais demais integrantes do grupo)*
- **Repositório GitHub:** *[Inserir URL do repositório após criação/push remoto]*

---

## 2. Objetivo, Público Previsto e Interação Principal
- **Objetivo:** Simular um setor de controle de aproximação aérea com pista única em **Terminal ASCII** no simulador MARS, no qual o usuário precisa pousar **4 aeronaves** (`VO-101` a `VO-404`) em até 20 turnos sem colisões, sem pane seca e sem invadir a pista (`00 NM`) sem autorização.
- **Público previsto:** Estudantes e docentes da disciplina de Arquitetura e Organização de Computadores interessados em simulações de sistemas discretos, manipulação de matrizes em memória e controle de fluxo em Assembly MIPS32.
- **Interação principal:** A cada turno, o simulador exibe o cabeçalho do setor, um **radar 2D ASCII** (`4000..1000 ft` × `00..07 NM`) e a tabela de status dos 4 voos. O controlador escolhe uma aeronave (`1..4`) para aplicar comandos (`1-Descer`, `2-Órbita`, `3-Pouso`, `4-Arremeter`, `0-Voltar`), avança o turno (`5`) ou encerra (`0`).

---

## 3. Entradas, Processamento e Saídas Esperadas

### Entradas
- Ação principal no turno (`0..5`) e comando de aeronave (`0..4`), lidos exclusivamente como texto via `syscall 8` (`read_validated_integer`), sem uso de `syscall 5`.

### Processamento
- Armazenamento e atualização da matriz `fleet_matrix` (`4 × 5 words`: `ID`, `ALT`, `DIST`, `FUEL`, `STATE`) indexada em memória por `get_aircraft_address`.
- Validação de regras operacionais: piso de altitude (`1000 ft`), requisitos de pouso (`ALT == 1000`, `DIST <= 3`, `runway_owner == 0`) e limite de arremetida (`DIST <= 4 NM`).
- Simulação de turno (`update_simulation_turn`): consumo de combustível (`-1`), avanço de distância (`-1 NM` fora de órbita), pouso ou acidente em `00 NM`, pane seca (`FUEL == 0`), verificação par-a-par de proximidade (`TCAS!`) e colisão aérea, e checagem de vitória (4 pousos) ou limite de 20 turnos.

### Saídas
- Interface textual 100% ASCII no console **Run I/O** do MARS (cabeçalho, grade 2D, tabela de status, eventos do turno e mensagem de encerramento).

---

## 4. Incorporação dos Requisitos Técnicos de MIPS
- **Estrutura de dados em memória:** Matriz `fleet_matrix` (`80 B` a partir de `0x10010000`) + tabelas de consulta (`state_names`, `end_messages`, `state_symbols`).
- **Decisões e repetições reais:** Laço principal de turnos, laços aninhados do radar 2D, parser léxico em `read_validated_integer`, atualização da frota e comparação par-a-par `(i < j)` de separação.
- **Procedimentos, convenções e pilha (`$sp`):** **6 procedimentos** com nomes explícitos (`main`, `get_aircraft_address`, `read_validated_integer`, `print_radar_and_table`, `read_and_execute_command`, `update_simulation_turn`), preservando `$ra` e `$s*` na pilha com retorno simétrico.
- **Tratamento robusto de entradas e encerramento:** Validação manual de dígitos via `syscall 8`, rejeição sem travar o MARS e encerramento limpo com `syscall 10`.
