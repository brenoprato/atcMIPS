# Casos de Teste Reproduzíveis — ATC-MIPS

Todos os casos abaixo são **100% determinísticos e reproduzíveis** diretamente pela interface gráfica do **MARS 4.5+** (testado no **MARS 4.6U**).

### Preparação antes de cada teste
1. Abra o **MARS** e carregue o arquivo [`src/atc_mips.asm`](../src/atc_mips.asm).
2. Confirme em **Settings → Memory Configuration** que a opção **Default** (`.data` em `0x10010000`) está selecionada.
3. Pressione **F3** (*Assemble*) e **F5** (*Run*), interagindo pelo painel **Run I/O** (pressione **Enter** após cada valor digitado).
4. Para iniciar um novo teste, pressione **F3** e **F5** novamente (ou **Reset**).

---

## Caso 1 — Uso Normal (Vitória com 4/4 Pousos)

- **Objetivo:** Sequenciar a descida e a autorização de pouso de todas as 4 aeronaves (`VO-101` a `VO-404`) até a vitória.
- **Passo a passo (entradas no Run I/O):**
  1. **Turno 1:** digite `1`, depois `3` *(autoriza pouso do `VO-101`, já em `1000 ft` e `02NM`)*.
  2. **Turno 2:** digite `2`, depois `1` *(desce `VO-202` para `1000 ft`; no fim do turno, `VO-101` pousa e libera a pista)*.
  3. **Turno 3:** digite `2`, depois `3` *(autoriza pouso do `VO-202` em `1000 ft, 02NM`)*.
  4. **Turno 4:** digite `3`, depois `1` *(desce `VO-303` para `2000 ft`; no fim do turno, `VO-202` pousa)*.
  5. **Turno 5:** digite `3`, depois `1` *(desce `VO-303` para `1000 ft`)*.
  6. **Turno 6:** digite `3`, depois `3` *(autoriza pouso do `VO-303` em `1000 ft, 01NM`; no fim do turno, `VO-303` pousa)*.
  7. **Turno 7:** digite `4`, depois `1` *(desce `VO-404` para `3000 ft`, saindo de `ORBITA` para `APROX`)*.
  8. **Turno 8:** digite `4`, depois `1` *(desce `VO-404` para `2000 ft`)*.
  9. **Turno 9:** digite `4`, depois `1` *(desce `VO-404` para `1000 ft`)*.
  10. **Turno 10:** digite `4`, depois `3` *(autoriza pouso do `VO-404` em `1000 ft, 03NM`)*.
  11. **Turno 11:** digite `5` *(avança todos os voos; `VO-404` vai para `01NM`)*.
  12. **Turno 12:** digite `5` *(avança todos os voos; `VO-404` chega em `00NM` e pousa)*.
- **Resultado esperado:** Cada aeronave pousa em sequência sem colisões nem pane seca, encerrando no Turno 12 com vitória.
- **Resultado observado:** Exibe `[POUSO] Voo pousou com seguranca!` para os 4 voos, mostra no estado final `TURNO 12/20 | Pousos: 4/4 | Pista(0=livre): 0`, tabela com os 4 voos em `POUSOU` (combustível restante `03`, `02`, `03` e `01`) e encerra com `=== VITORIA: Todos os 4 voos pousaram! ===`.
- **Justificativa:** Valida o fluxo principal completo — indexação da matriz `fleet_matrix`, reserva e liberação da pista única (`runway_owner`), consumo de combustível, avanço de distância, contagem de pousos e condição de vitória.

---

## Caso 2 — Entradas Inválidas, Comandos Negados e Saída Limpa

- **Objetivo:** Comprovar que entradas inválidas não travam o MARS e que comandos fora das regras são bloqueados sem gastar turno.
- **Passo a passo (entradas no Run I/O a partir do Turno 1):**
  1. Pressione apenas **Enter** *(linha vazia)* → deve exibir `Entrada invalida!`.
  2. Digite `abc` → deve exibir `Entrada invalida!`.
  3. Digite `9` *(fora do intervalo `0..5`)* → deve exibir `Entrada invalida!`.
  4. Digite `3` *(seleciona `VO-303`, em `3000 ft, 06NM`)* e depois `3` *(Pouso)* → deve exibir `Pouso negado (requer Alt=1000, Dist<=3 e Pista livre).`.
  5. Ainda no `VO-303`, digite `4` *(Arremeter)* → deve exibir `Arremetida negada (requer Dist<=4 NM).`.
  6. Digite `0` *(voltar ao menu principal sem gastar turno)*.
  7. Digite `1` *(seleciona `VO-101`, já em `1000 ft`)* e depois `1` *(Descer)* → deve exibir `Negado: ja esta em 1000 ft.`.
  8. Digite `0` *(voltar ao menu principal)* e depois `0` *(sair)*.
- **Resultado esperado:** Todas as entradas incorretas são rejeitadas sem exceção do simulador, o turno permanece em `1/20` e o programa encerra de forma limpa.
- **Resultado observado:** Todas as mensagens de erro/recusa apareceram exatamente como previsto, o turno não avançou e o programa terminou com `=== FIM: Encerrado pelo controlador. ===` (`syscall 10`).
- **Justificativa:** Comprova que `read_validated_integer` (`syscall 8`) evita travamentos do `syscall 5`, que as regras operacionais validam corretamente cada comando e que existe saída limpa.

---

## Caso 3 — Situações Limite (Acidentes, TCAS! e Arremetida)

### Subcaso 3A — Limite `00 NM` sem Autorização de Pouso
- **Passo a passo:**
  1. **Turno 1:** digite `5` *(avança todos; `VO-101` vai de `02NM` para `01NM` em `APROX`)*.
  2. **Turno 2:** digite `5` *(avança todos; `VO-101` atinge `00NM` sem estar autorizado)*.
- **Resultado esperado:** Acidente imediato ao cruzar a cabeceira `00 NM` sem autorização de pouso.
- **Resultado observado:** Exibe `[ACIDENTE] Limite 00 NM sem autorizacao! VO-101`, marca `[1X]` em `(1000ft, 00NM)` no radar final e encerra com `=== FIM: Operacao encerrada por acidente! ===`.
- **Justificativa:** Testa a fronteira inferior da matriz (`DIST == 0`) sem permissão de pouso.

### Subcaso 3B — Pane Seca (`Comb == 0`)
- **Passo a passo:**
  1. **Turno 1:** digite `1`, depois `2` *(coloca `VO-101` em `ORBITA` na distância `02NM`)*.
  2. **Turno 2:** digite `2`, depois `2` *(coloca `VO-202` em `ORBITA` na distância `03NM`)*.
  3. **Turnos 3, 4 e 5:** digite `5` em cada um dos três turnos *(avança todos)*.
- **Resultado esperado:** No Turno 5, o combustível do `VO-101` chega a `00` ainda em voo, disparando pane seca.
- **Resultado observado:** Exibe `[ACIDENTE] Pane seca! VO-101`, marca `[1X]` em `(1000ft, 02NM)`, mostra `Comb = 00` e `ACIDENTE` na tabela e encerra a simulação.
- **Justificativa:** Testa o limite de esgotamento de combustível com aeronave estacionada em órbita.

### Subcaso 3C — Alerta `TCAS!` e Colisão Aérea na Mesma Célula
- **Passo a passo:**
  1. **Turno 1:** digite `2`, depois `1` *(desce `VO-202` para `1000 ft`, mesma altitude do `VO-101`)*.
  2. **Turno 2:** digite `1`, depois `2` *(coloca `VO-101` em `ORBITA` em `01NM`; `VO-202` avança para `02NM`)*.
  3. **Turno 3:** digite `5` *(avança todos; `VO-202` entra em `01NM` junto com `VO-101`)*.
- **Resultado esperado:** Alerta `[TCAS!]` no fim do Turno 2 (`|ΔDist| == 1` na mesma altitude) e colisão aérea no fim do Turno 3 (`|ΔDist| == 0`).
- **Resultado observado:** No Turno 2 imprime `[TCAS!] Proximidade perigosa na mesma altitude!`; no Turno 3 imprime `[ACIDENTE] Colisao aerea na mesma celula!`, desenha `[XX]` em `(1000ft, 01NM)` e encerra por acidente.
- **Justificativa:** Valida a rotina par-a-par `(0 <= i < j < 4)` de verificação de proximidade e colisão.

### Subcaso 3D — Arremetida Tática (`Dist <= 4 NM`) e Conferência na Memória
- **Passo a passo:**
  1. **Turno 1:** digite `1`, depois `4` *(arremete `VO-101`, que está em `1000 ft, 02NM`)*.
  2. Observe o Turno 2 no painel **Run I/O** e digite `0` para encerrar.
  3. Abra a aba **Execute → Data Segment** do MARS em `0x10010000` (formato hexadecimal).
- **Resultado esperado:** `VO-101` sobe para `2000 ft`, volta para `06NM` após o turno e fica com `04` de combustível, refletido diretamente na primeira linha de `fleet_matrix`.
- **Resultado observado:** A tabela exibe `1 | VO-101 | 2000 | 06NM | 04 | APROX` e o Data Segment em `0x10010000..0x10010010` mostra `00000065` (`101`), `000007d0` (`2000`), `00000006` (`6`), `00000004` (`4`) e `00000000` (`APROX`).
- **Justificativa:** Confirma a manobra de arremetida e comprova a atualização exata dos offsets de `fleet_matrix` em memória.
