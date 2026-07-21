# Lab 3: Firewall dinâmico com eBPF Maps

Neste laboratório, um programa XDP consulta uma Hash Map para decidir se o endereço IPv4 de origem deve ser bloqueado. A política pode ser alterada com `bpftool` sem recompilar ou recarregar o programa eBPF.

Como o Containerlab cria interfaces virtuais `veth`, o Makefile anexa o programa com `xdpgeneric` para manter a compatibilidade com o WSL 2. Isso preserva o comportamento do programa e do map que serão estudados, mas o laboratório não representa uma medição de desempenho do XDP nativo em hardware.

## Objetivos

Ao final, você deverá conseguir:

- explicar por que eBPF Maps permitem manter estado;
- identificar chaves e valores de uma Hash Map;
- atualizar uma política a partir do userspace;
- comprovar que o programa reage imediatamente à atualização;
- distinguir o cliente bloqueado do cliente de controle.

## Topologia

O Containerlab cria três hosts:

```text
h2 (10.0.1.2/24) ── eth1  h1  eth2 ── h3 (10.0.2.2/24)
                         |     |
                    10.0.1.1 10.0.2.1
```

- `h1`: firewall; recebe XDP na interface conectada a `h2`;
- `h2`: cliente cujo endereço será inserido na blacklist;
- `h3`: cliente de controle que deve continuar alcançando `h1`.

## Como o Map representa a política

O programa define `blacklist` como `BPF_MAP_TYPE_HASH`:

```text
chave: IPv4 de origem (__u32)
valor: 1 para bloquear (__u32)
```

Para `10.0.1.2`, o Makefile grava:

```text
chave: 0a 00 01 02
valor: 01 00 00 00
```

A chave segue a ordem de bytes do endereço no pacote. O valor representa o inteiro `1` no ambiente x86-64 do curso.

## Arquivos

- `topology.yml`: descreve os três containers e dois enlaces;
- `xdp_fw_map.bpf.c`: declara a Hash Map e consulta o IPv4 de origem;
- `Makefile`: verifica, compila, executa, testa e limpa o laboratório.

## Antes de começar

Este passo a passo considera que o ambiente do README principal já foi preparado e que você está na raiz de `ebpf-grad-labs`.

## Executar

### 1. Entre no Lab 3

```bash
cd Lab3-Mapas_eBPF_Firewall
```

### 2. Conheça os alvos

```bash
make help
```

### 3. Verifique o ambiente

```bash
make check
```

### 4. Prepare o ambiente

```bash
make setup
```

O Makefile compila o programa, cria os três containers e configura os endereços. Nenhum programa XDP é anexado nessa etapa.

### 5. Execute uma etapa por vez

```bash
make test-step1
make test-step2
make test-step3
make test-step4
```

Cada etapa apresenta primeiro as saídas técnicas completas de `ping`, `ip` e `bpftool`. Somente depois aparece uma tela didática completa que traduz o que aconteceu. Para executar as quatro etapas automaticamente, use:

```bash
make test
```

A topologia permanece ativa ao final para inspeção.

## Como interpretar os testes

### 1/4: conectividade inicial

```bash
make test-step1
```

Antes de carregar XDP, `h2` e `h3` precisam alcançar `h1`.

Resultado esperado:

```text
SUCESSO: conectividade inicial confirmada.
```

Essa linha de base garante que uma falha posterior de `h2` foi causada pela blacklist, e não por um erro de endereçamento ou enlace.

### 2/4: XDP com map vazio

```bash
make test-step2
```

O programa XDP é anexado, mas a blacklist ainda não possui chaves. `h2` deve continuar passando.

Resultado esperado:

```text
SUCESSO: map vazio nao bloqueou h2.
```

### 3/4: inserção na blacklist

```bash
make test-step3
```

O Makefile localiza o map `blacklist` e utiliza `bpftool map update` para inserir `10.0.1.2` com valor `1`.

Depois da atualização:

- o ping de `h2` deve falhar;
- o ping de `h3` deve continuar funcionando.

Resultados esperados:

```text
SUCESSO: h2 foi bloqueado pela blacklist.
SUCESSO: h3 permaneceu permitido.
```

### 4/4: remoção da blacklist

```bash
make test-step4
```

O Makefile remove a chave com `bpftool map delete`. Sem recompilar o programa, `h2` volta a alcançar `h1`.

Resultado esperado:

```text
SUCESSO: h2 voltou a passar sem recompilar o programa.
```

Essa transição demonstra a comunicação entre userspace e o programa eBPF por meio do Map.

## Evidências do experimento

Quando o Makefile pedir Enter, a topologia ainda estará ativa. Em outro terminal, inspecione os programas e maps:

```bash
sudo bpftool prog list
sudo bpftool map list
sudo bpftool map show name blacklist
```

Ao final do teste automático, a chave de `h2` já terá sido removida. Para repetir manualmente o bloqueio, descubra o ID:

```bash
sudo bpftool map show name blacklist
```

Insira novamente:

```bash
sudo bpftool map update name blacklist \
  key hex 0a 00 01 02 \
  value hex 01 00 00 00
```

Teste:

```bash
sudo ip netns exec h2 ping -c 1 -W 2 10.0.1.1
```

Remova:

```bash
sudo bpftool map delete name blacklist key hex 0a 00 01 02
```

## Critérios de sucesso

O laboratório é considerado bem-sucedido quando:

1. `h2` e `h3` funcionam inicialmente;
2. XDP com map vazio não bloqueia `h2`;
3. inserir `h2` bloqueia apenas esse cliente;
4. remover `h2` restaura sua conectividade sem recompilação.

## Encerrar e limpar

Quando terminar os testes e a inspeção, destrua a topologia, remova os namespaces auxiliares e apague `xdp_fw_map.o`:

```bash
make clean
```

Confirme:

```bash
sudo docker ps --format '{{.Names}}' | grep clab-ebpf-lab3 || echo "Lab 3 removido"
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
make test
```

### `Peer MTU is too large to set XDP`

Essa mensagem indica que uma versão antiga do laboratório tentou anexar XDP nativo à interface `veth`. O Makefile atual utiliza XDP genérico. Atualize e execute novamente:

```bash
git pull
make clean
make setup
make test
```

### `map blacklist nao encontrado`

Confira se o programa XDP foi carregado:

```bash
sudo bpftool prog list
sudo bpftool map list
```

Depois limpe o ambiente e repita:

```bash
make clean
make setup
make test
```
