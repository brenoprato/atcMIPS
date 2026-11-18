# Fase 1 — Proposta do Projeto: ATC-MIPS

## 1. Identificação
- **Nome do produto:** **ATC-MIPS** (*Air Traffic Control* — Controle de Tráfego Aéreo / Radar de Aproximação de Pista)
- **Disciplina:** Arquitetura e Organização de Computadores — ICT/UNIFESP (Profa. Denise Stringhini)
- **Grupo / Integrantes:** Breno *(atualizar com eventuais demais integrantes do grupo)*
- **Repositório GitHub:** *[Inserir URL do repositório após criação/push remoto]*

---

## 2. Objetivo, Público Previsto e Interação Principal
- **Objetivo:** Simular um setor de controle de aproximação aérea com pista única em **Terminal ASCII** no simulador MARS, desafiando o usuário a gerenciar 6 voos em diferentes cenários operacionais até o pouso seguro, equilibrando altitude, espera em órbita, consumo de combustível e separação mínima.
- **Público previsto:** Estudantes e avaliadores da disciplina de Arquitetura e Organização de Computadores interessados em simulações interativas em Assembly MIPS com forte organização visual em modo texto e controle rigoroso de estado em memória.
- **Interação principal:** Após um briefing inicial explicativo e escolha entre 3 cenários determinísticos, o controlador visualiza a cada turno um painel dividido em 5 seções (`Caixa de Rádio`, `Cabeçalho do Setor`, `Radar 2D ASCII com Legenda`, `Tabela de Telemetria` e `Painel de Comando da Torre`). Ele pode comandar qualquer voo ativo (`1..6`), avançar o turno diretamente mantendo todos no curso (`7`), consultar o manual completo sem gastar turno (`8`) ou encerrar (`0`).

---

## 3. Entradas, Processamento e Saídas Esperadas

### Entradas
- Seleção inicial de cenário (`1..3`), consulta ao manual (`4`) ou encerramento (`0`).
- Seleção no painel da torre (`0..8`) e comandos individuais de voo (`0..6`), todos lidos exclusivamente como strings via `syscall 8` (`read_safe_int`).

### Processamento
- Inicialização de `fleet_matrix` (`6 aeronaves × 6 atributos`: `ID`, `ALT`, `DIST`, `FUEL`, `STATE`, `ALERT`) conforme o cenário escolhido.
- Validação de comandos aeronáuticos (limites `1000..4000 ft`, reserva única da pista em `ALT == 1000 ft` e `DIST <= 3 NM`, arremetida tática `+1000 ft / +3 NM`).
- Atualização de turno: movimento (`-1 NM` fora de órbita), consumo (`-1` combustível), pousos, arremetida automática (`00 NM` sem autorização), `MAYDAY` (`<= 3`), pane seca (`== 0`), verificação par-a-par de `TCAS!`/colisão, ativação de ondas e cálculo de pontuação (`current_score`) e classificação final (`Rank`).

### Saídas
- Painel ASCII organizado em 5 seções no console do MARS, relatório final com avaliação de desempenho (`RANK S` a `REPROVADO`) e alertas sonoros MIDI discretos (`syscall 31`).

### Exemplo de Uso
1. Na abertura, o usuário lê o briefing inicial e escolhe `1` (**Operacao Padrao**).
2. No Turno 1, `VO-101` está a `1000 ft, 2 NM` e pista `LIVRE`. O controlador digita `1` e depois `4` (Autorizar pouso).
3. A Caixa de Rádio confirma a autorização, avança os voos (`VO-101` vai para `1 NM` como `[1*]`), e no Turno 2, após comandar `2 -> 1` (`VO-202` desce para `1000 ft`), `VO-101` cruza `00 NM`, pousa com segurança (`+140 pts`), libera a pista e entra a onda `VO-505`.

---

## 4. Incorporação dos Requisitos Técnicos de MIPS
- **Estrutura de dados em memória:** Matriz `fleet_matrix` (`144 bytes`) iniciada em `0x10010000`, indexada por aritmética de deslocamentos (`(idx + 2*idx) << 3`), além de três tabelas constantes de cenário (`scenario_1_data..3`).
- **Decisões e repetições reais:** Laço principal de turnos, varredura da grade 2D (`4 altitudes × 11 distâncias × 6 aeronaves`), verificação par-a-par `O(n²)` de separação e colisão, parser léxico caractere a caractere em `read_safe_int`.
- **Procedimentos, parâmetros e pilha (`$sp`):** 14 procedimentos bem delimitados (`$a0..$a1`, `$v0..$v1`), preservando `$ra` e `$s0..$s5` na pilha com epílogos simétricos.
- **Tratamento robusto de entrada:** Proibição de `syscall 5`; rejeição de linhas vazias, texto e números fora da faixa sem travar o MARS.

---

## 5. Escopo e Divisão Inicial de Tarefas
- **Escopo entregue:** Briefing e manual integrados, 3 cenários determinísticos, radar 2D ASCII + tabela de telemetria + caixa de rádio organizada, 6 comandos por voo + atalho de avanço de turno (`7`) + ajuda (`8`), pontuação/ranking e feedback MIDI (`syscall 31`).
- **Divisão de tarefas (planejamento base):**
  1. Modelagem da matriz em memória, cenários determinísticos e E/S segura (`syscall 8`).
  2. Lógica de voo, separação `TCAS`, colisões, combustível e sistema de pontuação.
  3. Interface ASCII organizada em 5 seções, briefing, manual e alertas MIDI.
  4. Bateria de testes reproduzíveis no MARS CLI e documentação técnica.
