# Registro de Uso de Inteligência Artificial e Fontes — ATC-MIPS

## 1. Ferramentas Utilizadas e Finalidade
Durante o desenvolvimento do **ATC-MIPS**, utilizamos ferramentas de IA generativa como apoio ao **aprendizado de Assembly MIPS32** e produtividade no projeto, especificamente para:
- **Aprendizado de Assembly e syscalls do MARS:** compreender na prática o funcionamento e as convenções de `syscall 1` (imprimir inteiro), `syscall 4` (imprimir string), `syscall 8` (leitura segura de string sem travamento do `syscall 5`), `syscall 10` (encerramento limpo) e `syscall 11` (imprimir caractere), além do uso da pilha (`$sp`) e preservação de `$ra`/`$s*`.
- **Implementação e refatoração de algumas lógicas:** apoio na estruturação da matriz `fleet_matrix` (`4 × 5 words`), na validação léxica de inteiros (`read_validated_integer`), na checagem par-a-par de proximidade/colisão (`TCAS!`) e na simplificação final do código para uma versão enxuta e explicável linha a linha (661 linhas / 434 instruções úteis).
- **Formatação dos outputs no terminal:** organização visual do radar 2D ASCII e alinhamento em largura fixa das colunas da tabela de aeronaves (`Alt`, `0XNM` e `Comb` com 2 dígitos).
- **Apoio na documentação:** estruturação do `README.md`, da ficha técnica e dos roteiros reproduzíveis de teste.

Todo o código produzido com apoio da ferramenta foi estudado, revisado e testado diretamente no simulador MARS.

---

## 2. Exemplo Relevante de Uso, Adaptações e Correções

### Correção 1 — Exibição de Acidentes (`[kX]` e `[XX]`) no Radar Final
- **Situação observada:** Ao simplificar a rotina de desenho do radar (`print_radar_and_table`), a condição inicial ignorava qualquer voo com `STATE >= 3` (`bge $t2, 3, radar_scan_next`). Nos testes de colisão e pane seca (`STATE = 4`), percebeu-se que o radar final apagava as aeronaves acidentadas e não mostrava `[XX]` nem `[kX]`.
- **Adaptação aplicada:** Alterou-se o teste em [src/atc_mips.asm](../src/atc_mips.asm#L234-L235) para `beq $t2, 3, radar_scan_next` (ocultando apenas voos que já pousaram), ampliou-se o vetor `state_symbols` para `.byte ' ', '@', '*', ' ', 'X'` e ajustou-se `turn_air_collision` para saltar para `turn_pair_next_i`. Após o ajuste, os testes 3A, 3B e 3C passaram a exibir `[1X]` e `[XX]` exatamente na célula do acidente.

### Correção 2 — Alinhamento da Tabela de Aeronaves no Output
- **Situação observada:** A tabela original imprimia valores sem preenchimento (`1000` vs `0` em `Alt`, `2` em `Dist`, `5` vs `13` em `Comb`), deixando as barras `|` desalinhadas no terminal.
- **Adaptação aplicada:** Em `radar_table_loop` ([src/atc_mips.asm](../src/atc_mips.asm#L317-L345)), adicionou-se preenchimento de 3 espaços quando `ALT == 0`, formatação fixa `0XNM` para distância e zero à esquerda para combustível `< 10`, além da linha divisória no cabeçalho.

---

## 3. Verificação Concreta: Rastreamento Manual × Execução no MARS

Realizou-se o rastreamento manual da **aritmética de endereços (`get_aircraft_address`)**, da **arremetida (`command_go_around`)** e da **atualização de turno (`update_simulation_turn`)**, comparando com os valores exibidos no painel **Data Segment** do MARS no **Subcaso 3D** (Turno 1: `1` → `4`, depois `0` para encerrar).

### Rastreamento Manual ([src/atc_mips.asm](../src/atc_mips.asm), `L116–L122`, `L462–L479` e `L515–L535`)
1. **Endereço do Slot 1 (`idx = 0`, `VO-101`):**
   - `get_aircraft_address(0)`: `(0 << 4) + (0 << 2) = 0` → `$v0 = 0x10010000`.
   - Estado inicial em `0x10010000..0x10010010`: `ID = 101 (0x65)`, `ALT = 1000 (0x3e8)`, `DIST = 2`, `FUEL = 5`, `STATE = 0 (APROX)`.
2. **Comando `4` (Arremeter) em `command_go_around`:**
   - Verifica `DIST <= 4`: `2 <= 4` (aceito).
   - `ALT = 1000 + 1000 = 2000 (0x7d0)` → gravado em `4($s1) = 0x10010004`.
   - `DIST = 7` → gravado em `8($s1) = 0x10010008`.
   - `STATE = 0` → gravado em `16($s1) = 0x10010010`.
3. **Atualização do Turno 1 em `update_simulation_turn`:**
   - `VO-101` (`0x10010000`): `FUEL: 5 -> 4 (0x4)`, `DIST: 7 -> 6 (0x6)`, `ALT = 2000 (0x7d0)`, `STATE = 0`.
   - `VO-202` (`0x10010014`, `idx = 1 → +20 B = +0x14`): `ID = 202 (0xca)`, `ALT = 2000 (0x7d0)`, `DIST: 4 -> 3 (0x3)`, `FUEL: 6 -> 5 (0x5)`, `STATE = 0`.
   - `VO-303` (`0x10010028`, `idx = 2 → +40 B = +0x28`): `ID = 303 (0x12f)`, `ALT = 3000 (0xbb8)`, `DIST: 6 -> 5 (0x5)`, `FUEL: 9 -> 8 (0x8)`, `STATE = 0`.
   - `VO-404` (`0x1001003C`, `idx = 3 → +60 B = +0x3c`): `ID = 404 (0x194)`, `ALT = 4000 (0xfa0)`, `DIST = 6 (0x6, em ORBITA)`, `FUEL: 13 -> 12 (0xc)`, `STATE = 1`.
4. **Conferência no Data Segment do MARS (`0x10010000` a `0x1001004C`):**
   - `0x10010000`: `00000065  000007d0  00000006  00000004  00000000` (`VO-101`)
   - `0x10010014`: `000000ca  000007d0  00000003  00000005  00000000` (`VO-202`)
   - `0x10010028`: `0000012f  00000bb8  00000005  00000008  00000000` (`VO-303`)
   - `0x1001003C`: `00000194  00000fa0  00000006  0000000c  00000001` (`VO-404`)
   - **Resultado:** Os 20 words dumpados pelo MARS coincidem 100% com o rastreamento manual.

---

## 4. Fontes Externas
- Documentação oficial de syscalls e convenções MIPS do simulador **MARS 4.5+**.
- Inspeção do comportamento de `syscall 8` (`read_string`) no MARS para lidar corretamente com entradas vazias (`"\n"`) e fim de entrada (`EOF`).
