# Lab 2: XDP ingress vs. TC egress

Neste laboratório, vamos comparar dois pontos de processamento de pacotes no kernel Linux:

- **XDP (eXpress Data Path):** processa pacotes recebidos muito cedo no caminho de entrada;
- **TC (Traffic Control):** processa pacotes em um ponto posterior da pilha e pode atuar no ingresso ou na saída.

O experimento utiliza XDP para descartar ICMP no ingresso de `h1` e TC para descartar TCP destinado à porta 80 na saída de `h2`.

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
h1 (172.20.20.1/24) eth1 ─── eth1 h2 (172.20.20.2/24)
```

- `h1` recebe o programa XDP em `eth1` e executa um servidor TCP na porta 80;
- `h2` gera ping e conexões TCP e recebe o filtro TC egress em `eth1`.

## Arquivos

- `topology.yml`: descreve os containers e o enlace;
- `xdp_drop_icmp.bpf.c`: retorna `XDP_DROP` para pacotes IPv4/ICMP;
- `tc_egress_drop.bpf.c`: retorna `TC_ACT_SHOT` para TCP com destino à porta 80;
- `Makefile`: verifica, compila, executa, testa e limpa o laboratório.

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

### 4. Execute o experimento

```bash
make run
```

O Makefile compila os programas, cria a topologia, configura os endereços e executa quatro testes.

## Como interpretar os testes

### XDP 1/2: linha de base

Antes de anexar XDP, `h2` envia ICMP para `h1`:

```text
h2 ── ping ──> h1
```

O ping precisa funcionar. Se ele já falhar, o experimento é interrompido porque uma falha posterior não provaria a atuação do XDP.

Resultado esperado:

```text
SUCESSO: ping funcionou sem XDP.
```

### XDP 2/2: filtro no ingresso

O programa é anexado a `eth1` de `h1`. Pacotes ICMP recebidos passam pelo hook XDP e retornam `XDP_DROP`.

Resultado esperado:

```text
SUCESSO: XDP bloqueou o ICMP no ingresso de h1.
```

### TC 1/2: linha de base

O Makefile inicia um servidor com Netcat na porta 80 de `h1`. Antes do TC, `h2` precisa conseguir abrir uma conexão TCP.

Resultado esperado:

```text
SUCESSO: conexao TCP/80 funcionou sem TC.
```

### TC 2/2: filtro no egress

O classificador TC é anexado ao egress de `eth1` em `h2`. Quando o destino TCP é a porta 80, o programa retorna `TC_ACT_SHOT`.

Resultado esperado:

```text
SUCESSO: TC bloqueou TCP/80 no egress de h2.
```

## Evidências do experimento

Quando o Makefile pedir Enter, a topologia ainda estará ativa. Em outro terminal, você pode inspecionar:

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

Volte ao terminal de `make run` e pressione Enter. O Makefile destrói a topologia, remove os namespaces auxiliares e apaga `xdp.o` e `tc.o`.

Se uma execução for interrompida, execute:

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
make run
```

### Falha durante a instalação de pacotes nos containers

Confirme o acesso à internet e tente novamente. Na primeira execução, os containers instalam `iproute2`, `iputils-ping` e `netcat-openbsd`.

### XDP não pode ser anexado

Confira a mensagem do verifier e as capacidades do kernel:

```bash
sudo bpftool feature probe kernel
```

Depois limpe a topologia:

```bash
make clean
```
