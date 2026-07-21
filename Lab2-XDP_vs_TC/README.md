# Lab 2: XDP ingress vs. TC egress

Neste laboratório, vamos comparar dois pontos de processamento de pacotes no kernel Linux:

- **XDP (eXpress Data Path):** processa pacotes recebidos muito cedo no caminho de entrada;
- **TC (Traffic Control):** processa pacotes em um ponto posterior da pilha e pode atuar no ingresso ou na saída.

O experimento utiliza XDP para descartar ICMP no ingresso de `h1` e TC para descartar TCP destinado à porta 80 na saída de `h2`.

### Modo XDP utilizado no laboratório

O Containerlab conecta os hosts com interfaces virtuais do tipo `veth`. Por compatibilidade com essas interfaces no WSL 2, o Makefile anexa o programa com `xdpgeneric`, isto é, no modo XDP genérico.

O programa, o hook e as ações XDP continuam sendo estudados normalmente. Entretanto, este experimento demonstra o comportamento do filtro, e não o desempenho do XDP nativo executado pelo driver de uma interface física.

## Objetivos

Ao final, você deverá conseguir:

- diferenciar ingress e egress;
- explicar onde XDP e TC atuam;
- carregar programas eBPF em interfaces de namespaces de rede;
- comparar o comportamento antes e depois de cada filtro;
- reconhecer por que um teste de linha de base evita falsos positivos.

## Topologia

O Containerlab cria dois hosts Linux conectados diretamente:

```text
h1 (10.10.12.1/24) eth1 ─── eth1 h2 (10.10.12.2/24)
```

- `h1` recebe o programa XDP em `eth1` e executa um servidor TCP na porta 80;
- `h2` gera ping e conexões TCP e recebe o filtro TC egress em `eth1`.

A rede experimental `10.10.12.0/24` é diferente da rede administrativa do Containerlab. Essa separação garante que os pacotes de teste atravessem `eth1`, em vez de seguirem pela interface administrativa `eth0` e desviarem dos programas eBPF.

## Arquivos

- `topology.yml`: descreve os containers e o enlace;
- `xdp_drop_icmp.bpf.c`: retorna `XDP_DROP` para pacotes IPv4/ICMP;
- `tc_egress_drop.bpf.c`: retorna `TC_ACT_SHOT` para TCP com destino à porta 80;
- `Makefile`: verifica, compila, executa, testa e limpa o laboratório.

## Ferramentas de visualização

O laboratório utiliza ferramentas de terminal instaladas automaticamente nos containers:

- `ping`: mostra cada resposta ICMP e o percentual de perda;
- `tcpdump`: exibe os pacotes que realmente atravessam `eth1`;
- `ip -details link`: mostra o programa XDP anexado à interface;
- `nc -v`: mostra se a conexão TCP foi estabelecida ou expirou;
- `tc -s`: mostra o classificador TC e seus contadores.

Essa combinação permite observar o experimento diretamente no terminal e é mais leve que uma interface gráfica para as máquinas do curso.

## Antes de começar

Este passo a passo considera que o ambiente do README principal já foi preparado e que você está na raiz de `ebpf-grad-labs`.

Confirme:

```bash
pwd
ls
```

## Executar

### 1. Entre no Lab 2

```bash
cd Lab2-XDP_vs_TC
```

### 2. Conheça os alvos

```bash
make help
```

### 3. Verifique o ambiente

```bash
make check
```

Essa etapa confirma Clang, Docker, Containerlab, `ip`, `tc` e o Docker daemon.

### 4. Prepare o ambiente

```bash
make setup
```
O Makefile compila os programas, cria os dois containers e configura a rede experimental. Nenhum filtro é anexado e nenhum teste é executado nessa etapa.

Depois de `make setup`, a topologia permanece ativa durante os experimentos e só é removida quando você executa `make clean`.

## Experimentos

O Lab 2 possui dois experimentos separados. Primeiro estudamos XDP no ingresso de `h1`; depois estudamos TC na saída de `h2`.

```bash
# Experimento XDP
make test-xdp-baseline
make test-xdp-filter
make detach-xdp

# Experimento TC
make test-tc-baseline
make test-tc-filter
make detach-tc
```


## Experimento 1: XDP no ingresso

### O que estamos estudando

XDP permite executar um programa eBPF quando um pacote entra em uma interface de rede. Ele atua antes de grande parte do processamento tradicional da pilha Linux.

Neste laboratório, o programa `xdp_drop_icmp.bpf.c` é anexado ao ingresso de `eth1` em `h1`:

```text
h2 envia ICMP
      |
      v
h1:eth1 -- entrada --> XDP --> pilha de rede de h1
                         |
                         +-- XDP_DROP: descarta ICMP
                         +-- XDP_PASS: permite os demais pacotes
```

O programa verifica o protocolo do pacote. Quando encontra ICMP, utilizado pelo `ping`, retorna `XDP_DROP`. Para os demais protocolos, retorna `XDP_PASS`.

Usaremos dois testes: uma linha de base sem XDP e a repetição do mesmo ping com XDP. Comparar os dois resultados permite atribuir o bloqueio ao programa eBPF.

### XDP — teste 1/2: linha de base sem filtro

Execute:

```bash
make test-xdp-baseline
```

Antes de anexar XDP, `h2` envia ICMP para `h1`:

```text
h2 ── ping ──> h1
```

O Makefile inicia `tcpdump` na `eth1` de `h1` e envia dois pings. As saídas técnicas de `tcpdump` e `ping` são exibidas durante a execução e, quando os comandos terminam, o Makefile apresenta um resumo didático que interpreta os resultados observados.

Essa ordem é intencional: alunos curiosos podem examinar toda a evidência técnica, enquanto a tela final oferece uma explicação acessível sem se misturar aos dados brutos.

Resultado esperado:

```text
============================================================
 XDP - TESTE 1/2: comunicacao antes de ativar o filtro
============================================================

OBJETIVO
  Verificar se h2 consegue conversar com h1 sem nenhum
  bloqueio eBPF. Este resultado sera nossa linha de base.

PREPARACAO
  [OK] XDP esta desativado em h1.
  [OK] tcpdump observou a interface eth1.

ACAO
  h2 enviou 2 pedidos de ping para h1 (10.10.12.1).
  ICMP e o protocolo utilizado pelo comando ping.

O QUE ACONTECEU
1. h2 enviou 2 pedidos de ping para h1.
2. h1 recebeu os 2 pedidos pela interface eth1.
3. h1 enviou 2 respostas para h2.
4. h2 recebeu as 2 respostas: nenhuma foi perdida.

PACOTES OBSERVADOS PELO TCPDUMP
  Pedidos:   2  |  h2 (10.10.12.2) -> h1 (10.10.12.1)
  Respostas: 2  |  h1 (10.10.12.1) -> h2 (10.10.12.2)

CONCLUSAO
  [SUCESSO] A rede funciona normalmente sem o XDP.
```

Essa é a linha de base: ela prova que endereçamento, enlace e rota funcionam antes do filtro.

### XDP — teste 2/2: filtro no ingresso

Execute:

```bash
make test-xdp-filter
```

O programa é anexado a `eth1` de `h1`. Pacotes ICMP recebidos passam pelo hook XDP e retornam `XDP_DROP`.

O comando `ip -details link` mostra `prog/xdp` na interface. Em seguida, a saída real do ping deve mostrar que nenhuma resposta chegou:

```text
2 packets transmitted, 0 received, 100% packet loss
```

Resultado esperado:

```text
SUCESSO: XDP_DROP bloqueou o ICMP no ingresso de h1.
```

O ping falhar agora é uma evidência válida porque a mesma comunicação funcionou no teste XDP anterior.

### Encerre o experimento XDP

Depois de observar o bloqueio, desanexe o programa antes de iniciar o experimento TC:

```bash
make detach-xdp
```

Esse comando remove somente o XDP de `h1:eth1`. Os containers, os endereços e a topologia permanecem ativos para o experimento seguinte.

## Experimento 2: TC na saída

### O que estamos estudando

TC, ou Traffic Control, oferece hooks eBPF associados ao sistema de controle de tráfego do Linux. Diferentemente do experimento XDP, usaremos o hook de **egress**, que observa os pacotes quando eles estão saindo de `h2`.

O programa `tc_egress_drop.bpf.c` é anexado ao egress de `eth1` em `h2`:

```text
aplicacao em h2 tenta conectar na porta 80
                    |
                    v
pilha de rede de h2 --> TC egress --> h2:eth1 --> h1
                           |
                           +-- TC_ACT_SHOT: descarta TCP/80
                           +-- TC_ACT_OK: permite os demais pacotes
```

Agora o tráfego testado não é ICMP, mas uma conexão TCP destinada à porta 80. O Netcat cria o servidor e tenta estabelecer a conexão; `tcpdump` e os contadores do TC fornecem as evidências técnicas.

### TC — teste 1/2: linha de base sem filtro

Execute:

```bash
make test-tc-baseline
```

O Makefile inicia um servidor com Netcat na porta 80 de `h1`. Antes do TC, `h2` precisa conseguir abrir uma conexão TCP.

O `tcpdump` mostra a negociação na `eth1` de `h1`, enquanto `nc -v` apresenta:

```text
Connection to 10.10.12.1 80 port [tcp/http] succeeded!
```

Resultado esperado:

```text
SUCESSO: Netcat e tcpdump comprovam que TCP/80 funcionou sem TC.
```

Essa linha de base prova que o servidor, a porta e o caminho de rede funcionam antes do filtro TC.

### TC — teste 2/2: filtro no egress

Execute:

```bash
make test-tc-filter
```

O classificador TC é anexado ao egress de `eth1` em `h2`. Quando o destino TCP é a porta 80, o programa retorna `TC_ACT_SHOT`.

O Makefile mostra primeiro o filtro anexado. A tentativa de conexão deve expirar e, depois, `tc -s` exibe os contadores do classificador que processou o pacote.

Resultado esperado:

```text
SUCESSO: TC bloqueou TCP/80 no egress de h2.
```

### Encerre o experimento TC

Depois de observar os contadores e o bloqueio, remova o classificador TC:

```bash
make detach-tc
```

Esse comando remove o `clsact` e o programa eBPF anexado ao egress de `h2:eth1`, mas preserva a topologia até que `make clean` seja executado.

## Comparando XDP e TC

Os dois experimentos descartam pacotes com programas eBPF, mas fazem isso em locais e momentos diferentes:

| Característica | XDP neste laboratório | TC neste laboratório |
|---|---|---|
| Direção observada | Ingresso | Egress |
| Interface | `h1:eth1` | `h2:eth1` |
| Momento | Muito cedo na entrada | Na saída, depois da pilha de rede |
| Tráfego testado | ICMP do `ping` | TCP destinado à porta 80 |
| Ação de descarte | `XDP_DROP` | `TC_ACT_SHOT` |
| Ferramenta principal de evidência | `ping`, `tcpdump` e `ip -details` | Netcat, `tcpdump` e `tc -s` |

O objetivo não é afirmar que uma tecnologia é sempre melhor que a outra. A escolha depende do ponto do caminho de rede em que o programa precisa atuar e das informações necessárias para tomar a decisão.

Neste exemplo:

- XDP demonstra uma decisão muito antecipada sobre pacotes recebidos por `h1`;
- TC demonstra uma política aplicada aos pacotes que tentam sair de `h2`;
- as linhas de base mostram que ambos os bloqueios foram causados pelos programas eBPF, e não por uma falha prévia da rede.

## Evidências do experimento

A topologia continua ativa depois de cada teste. Em outro terminal, você também pode inspecionar:

```bash
sudo ip netns exec h1 ip -details link show dev eth1
```

```bash
sudo ip netns exec h2 tc filter show dev eth1 egress
```

```bash
sudo bpftool prog list
```

O teste é bem-sucedido quando:

1. ICMP funciona antes e falha depois do XDP;
2. TCP/80 funciona antes e falha depois do TC;
3. os programas aparecem anexados nos pontos esperados.

## Encerrar e limpar

Quando terminar os testes e a inspeção, destrua a topologia, remova os namespaces auxiliares e apague `xdp.o` e `tc.o`:

```bash
make clean
```

Confirme:

```bash
sudo docker ps --format '{{.Names}}' | grep clab-ebpf-lab2 || echo "Lab 2 removido"
```

## Solução de problemas

### Docker daemon indisponível

```bash
sudo service docker start
make check
```

### Uma topologia anterior ainda está ativa

```bash
make clean
make setup
make test-xdp-baseline
```

### Falha durante a instalação de pacotes nos containers

Confirme o acesso à internet e tente novamente. Na primeira execução, os containers instalam `iproute2`, `iputils-ping`, `netcat-openbsd` e `tcpdump`.

### Falha ao anexar o programa XDP

Primeiro, remova qualquer programa XDP que tenha permanecido anexado e repita o teste:

```bash
make detach-xdp
make test-xdp-filter
```

Se a falha continuar, confira se o kernel oferece o tipo de programa XDP:

```bash
sudo bpftool feature probe kernel | grep -i -A 8 xdp
```

Confira também o estado da interface virtual:

```bash
sudo ip netns exec h1 ip -details link show dev eth1
```

Se o kernel WSL estiver desatualizado, execute no PowerShell do Windows:

```powershell
wsl --update
wsl --shutdown
```

Abra novamente o Ubuntu, inicie o Docker e recrie o laboratório:

```bash
sudo service docker start
cd ~/ebpf-grad-labs/Lab2-XDP_vs_TC
make clean
make setup
make test-xdp-baseline
make test-xdp-filter
```
