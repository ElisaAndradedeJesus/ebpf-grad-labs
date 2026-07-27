# Lab 3: Firewall dinâmico com eBPF Maps

Neste laboratório, um programa XDP consulta uma Hash Map para decidir se o endereço IPv4 de origem deve ser bloqueado. A política pode ser alterada com `bpftool`, a partir do userspace, sem recompilar nem recarregar o programa eBPF.

Como o Containerlab cria interfaces virtuais `veth`, o Makefile utiliza XDP genérico (`xdpgeneric`) para manter a compatibilidade com o WSL 2. O comportamento do programa e do Map é preservado, mas este laboratório não mede o desempenho do XDP nativo em hardware.

## Objetivos

Ao final, você deverá conseguir:

- explicar por que eBPF Maps permitem manter estado;
- identificar as chaves e os valores de uma Hash Map;
- atualizar uma política eBPF pelo userspace;
- observar a mudança da política sem recompilar o programa;
- comprovar que somente a origem inserida na blacklist é bloqueada.

## Topologia

O Containerlab cria dois hosts ligados pelo mesmo enlace:

```text
                    programa XDP
                          ↓
h2:eth1 ───────────────── h1:eth1
10.0.1.2                  10.0.1.1
10.0.1.3
```

O `h2` possui dois endereços IPv4 na mesma interface:

- `10.0.1.2`: endereço que será inserido na blacklist;
- `10.0.1.3`: endereço de controle, que não será inserido no Map.

Os testes escolhem explicitamente qual endereço o `ping` usará como origem. Assim, os pacotes de `10.0.1.2` e `10.0.1.3` percorrem exatamente o mesmo caminho e atravessam o mesmo programa XDP em `h1:eth1`.

Isso é importante: se o endereço de controle utilizasse outra interface, sua passagem não provaria que o Map foi seletivo. Neste experimento, quando `10.0.1.2` é bloqueado e `10.0.1.3` continua funcionando, a diferença só pode ser explicada pelo conteúdo da blacklist.

## Como o Map representa a política

O programa define `blacklist` como `BPF_MAP_TYPE_HASH`:

```text
chave: endereço IPv4 de origem (__u32)
valor: 1 para bloquear (__u32)
```

Para bloquear `10.0.1.2`, o Makefile grava:

```text
chave: 0a 00 01 02
valor: 01 00 00 00
```

A chave segue a ordem dos bytes do endereço presente no pacote. O valor representa o inteiro `1` no ambiente x86-64 usado pelo curso.

Para cada pacote IPv4 recebido, o programa:

1. lê o endereço de origem;
2. procura esse endereço na Hash Map;
3. retorna `XDP_DROP` quando encontra o valor `1`;
4. retorna `XDP_PASS` nos demais casos.

## Arquivos

- `topology.yml`: descreve os dois containers e o enlace entre eles;
- `xdp_fw_map.bpf.c`: declara a Hash Map e implementa a decisão do XDP;
- `Makefile`: verifica o ambiente, compila, prepara, testa e limpa o laboratório.

## Antes de começar

Este passo a passo considera que o ambiente descrito no README principal já foi preparado e que o terminal está na raiz de `ebpf-grad-labs`.

## Preparar o laboratório

### 1. Entre na pasta

```bash
cd Lab3-Mapas_eBPF_Firewall
```

### 2. Conheça os comandos disponíveis

```bash
make help
```

### 3. Verifique as dependências

```bash
make check
```

### 4. Monte o ambiente

```bash
make setup
```

Esse comando compila o programa, cria `h1` e `h2` e configura os três endereços IPv4. Ele ainda não anexa o XDP e não altera a blacklist.

## Executar o experimento

Os testes devem ser executados na ordem apresentada. Cada comando mostra primeiro as saídas técnicas completas de `ping`, `ip` e `bpftool`. Ao final, uma tela separada interpreta o resultado.

### Experimento 1: estabelecer a linha de base

```bash
make test-baseline
```

O XDP permanece desativado. O Makefile executa dois pings:

```text
origem 10.0.1.2 ──→ 10.0.1.1
origem 10.0.1.3 ──→ 10.0.1.1
```

Os dois devem funcionar. Essa linha de base demonstra que os endereços e o enlace estão corretos antes da aplicação do firewall.

### Experimento 2: anexar XDP com a blacklist vazia

```bash
make test-empty-map
```

O Makefile:

1. anexa o programa em modo XDP genérico ao ingresso de `h1:eth1`;
2. localiza e registra o ID do Map criado por esse programa;
3. mostra que a blacklist está vazia;
4. envia pacotes com origem `10.0.1.2`.

Como nenhuma chave foi cadastrada, a busca no Map não encontra o endereço e o programa retorna `XDP_PASS`. O ping deve funcionar.

### Experimento 3: alterar a política pelo Map

```bash
make test-block
```

O Makefile insere `10.0.1.2` na blacklist com `bpftool map update`. O programa eBPF não é recompilado nem recarregado.

Depois da atualização, dois fluxos atravessam o mesmo XDP:

```text
10.0.1.2 ──→ h1:eth1 ──→ encontrado no Map ──→ XDP_DROP
10.0.1.3 ──→ h1:eth1 ──→ ausente no Map     ──→ XDP_PASS
```

O ping com origem `10.0.1.2` deve falhar, enquanto o ping com origem `10.0.1.3` deve continuar funcionando. Essa comparação demonstra que o bloqueio é seletivo e foi provocado pelo conteúdo do Map.

Para `10.0.1.2`, a saída técnica deve mostrar que os dois pacotes foram
enviados, mas nenhuma resposta chegou:

```text
10.0.1.2 DEVE SER BLOQUEADO
------------------------------------------------------------
PING 10.0.1.1 (10.0.1.1) from 10.0.1.2 : 56(84) bytes of data.

--- 10.0.1.1 ping statistics ---
2 packets transmitted, 0 received, 100% packet loss
```

Logo depois, o teste com origem `10.0.1.3` deve exibir respostas de `h1` e
terminar sem perda:

```text
10.0.1.3 DEVE CONTINUAR PERMITIDO
------------------------------------------------------------
64 bytes from 10.0.1.1: icmp_seq=1 ttl=64 time=...
64 bytes from 10.0.1.1: icmp_seq=2 ttl=64 time=...

--- 10.0.1.1 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss
```

Os tempos e alguns detalhes da saída podem variar. As evidências importantes
são `100% packet loss` para `10.0.1.2` e `0% packet loss` para `10.0.1.3`.

### Experimento 4: remover a origem da blacklist

```bash
make test-unblock
```

O Makefile remove `10.0.1.2` com `bpftool map delete` e repete o ping. Como a busca deixa de encontrar a chave, o programa volta a retornar `XDP_PASS` e a conectividade é restaurada imediatamente.

Essa transição mostra a comunicação entre o userspace e o programa eBPF por meio do Map.

## Inspecionar o laboratório

Enquanto a topologia e o XDP estiverem ativos, você pode consultar os objetos em outro terminal:

```bash
sudo bpftool prog list
sudo bpftool map list
sudo ip netns exec h1 ip -details link show dev eth1
```

O Makefile guarda temporariamente o ID do Map em `/tmp/ebpf-lab3-map-id`. Para exibir a blacklist usada pelo experimento:

```bash
sudo bpftool map dump id "$(cat /tmp/ebpf-lab3-map-id)"
```

## Desanexar somente o XDP

Depois dos testes, desanexe o programa sem destruir os containers:

```bash
make detach-xdp
```

A topologia permanecerá ativa. Você poderá repetir o experimento desde a linha de base ou inspecionar a rede sem o firewall.

## Critérios de sucesso

O laboratório é considerado bem-sucedido quando:

1. os dois endereços alcançam `h1` sem XDP;
2. o XDP com a blacklist vazia permite `10.0.1.2`;
3. a inserção no Map bloqueia `10.0.1.2`;
4. `10.0.1.3` continua permitido pelo mesmo programa XDP;
5. a remoção da chave restaura `10.0.1.2` sem recompilação.

## Encerrar e limpar

Quando terminar, destrua a topologia, remova os namespaces auxiliares, desfaça os objetos e apague o arquivo compilado:

```bash
make clean
```

Confirme que os containers foram removidos:

```bash
sudo docker ps --format '{{.Names}}' | grep clab-ebpf-lab3 || echo "Lab 3 removido"
```

## Solução de problemas

### Docker não respondeu

```bash
sudo service docker start
sudo docker info
make check
```

### O ambiente ainda não foi preparado

Se um teste solicitar `make setup`, execute:

```bash
make clean
make setup
```

Depois retome o experimento desejado. Para `test-block` e `test-unblock`, respeite a ordem indicada no tutorial, pois essas etapas dependem do Map criado e atualizado anteriormente.

### Não foi possível anexar o XDP genérico

Limpe uma possível execução incompleta e verifique o suporte do kernel:

```bash
make clean
sudo bpftool feature probe kernel
make setup
make test-baseline
make test-empty-map
```

Se `bpftool feature probe kernel` indicar que XDP ou os tipos de Map necessários não estão disponíveis, confira se o WSL 2 e o kernel foram atualizados conforme o README principal.

### O Map registrado não existe mais

Isso acontece quando o programa XDP foi desanexado depois da criação do Map. Crie uma nova instância:

```bash
make test-empty-map
make test-block
```
