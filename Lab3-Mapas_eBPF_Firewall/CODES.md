# Análise do código: firewall XDP com eBPF Map

Este laboratório utiliza um programa XDP para consultar uma lista dinâmica de
endereços IPv4 bloqueados. A lista é armazenada em um eBPF Map chamado
`blacklist` e pode ser alterada pelo userspace sem recompilar nem recarregar o
programa.

O programa realiza quatro tarefas principais:

1. declara a Hash Map que representa a política de bloqueio;
2. valida e interpreta os cabeçalhos Ethernet e IPv4;
3. procura o endereço IPv4 de origem na Map;
4. descarta ou permite o pacote de acordo com o resultado da busca.

## 1. O programa XDP comentado

```c
#include <linux/bpf.h>       // Tipos, contexto e ações do eBPF/XDP.
#include <linux/if_ether.h>  // Estrutura do cabeçalho Ethernet.
#include <linux/ip.h>        // Estrutura do cabeçalho IPv4.
#include <bpf/bpf_helpers.h> // Macros SEC(), definição de Maps e helpers.
#include <bpf/bpf_endian.h>  // Conversões de ordem de bytes.

/*
 * Declara uma Hash Map chamada blacklist.
 *
 * A chave é um endereço IPv4 de origem, representado por __u32. O valor
 * também é um inteiro de 32 bits e indica se o endereço deve ser bloqueado:
 * neste laboratório, o valor 1 significa "bloquear".
 *
 * A seção .maps permite que o loader identifique a definição e solicite ao
 * kernel a criação da Map durante o carregamento do objeto eBPF.
 */
struct {
    /*
     * Uma Hash Map armazena pares de chave e valor e oferece busca eficiente
     * pelo endereço IPv4 usado como chave.
     */
    __uint(type, BPF_MAP_TYPE_HASH);

    /* Limita a blacklist a 1.024 chaves simultâneas. */
    __uint(max_entries, 1024);

    /* Cada chave contém um endereço IPv4 de origem. */
    __type(key, __u32);

    /* Cada valor contém a decisão associada ao endereço. */
    __type(value, __u32);
} blacklist SEC(".maps");

/*
 * SEC("xdp") define o tipo e o ponto de anexação do programa. Quando ele
 * estiver anexado a uma interface, será executado na entrada dos pacotes,
 * antes de eles avançarem pela pilha de rede do kernel.
 *
 * O contexto xdp_md fornece metadados do pacote, incluindo os endereços que
 * delimitam sua região de memória.
 */
SEC("xdp")
int xdp_firewall(struct xdp_md *ctx) {
    /*
     * ctx armazena os endereços do pacote como inteiros. As conversões abaixo
     * produzem ponteiros que podem ser utilizados pelo programa:
     *
     * - data aponta para o primeiro byte do pacote;
     * - data_end aponta para o limite final de sua região de memória.
     */
    void *data_end = (void *)(long)ctx->data_end;
    void *data = (void *)(long)ctx->data;

    /*
     * Interpreta os primeiros bytes como um cabeçalho Ethernet. Essa
     * atribuição ainda não acessa nenhum campo do cabeçalho.
     */
    struct ethhdr *eth = data;

    /*
     * Antes de ler o cabeçalho, o programa precisa provar ao eBPF Verifier
     * que toda a estrutura está dentro dos limites do pacote.
     *
     * Como eth é um ponteiro para struct ethhdr, eth + 1 aponta para o
     * primeiro byte após um cabeçalho Ethernet completo. Se esse endereço
     * ultrapassar data_end, não há bytes suficientes para uma leitura segura.
     * Nesse caso, o pacote é liberado sem ser analisado pelo firewall.
     */
    if ((void *)(eth + 1) > data_end) return XDP_PASS;

    /*
     * h_proto identifica o protocolo transportado pelo quadro Ethernet.
     * O campo está armazenado em ordem de bytes de rede. bpf_htons() converte
     * ETH_P_IP para o mesmo formato antes da comparação.
     *
     * Pacotes que não carregam IPv4 ficam fora da política deste exemplo e
     * continuam normalmente.
     */
    if (eth->h_proto != bpf_htons(ETH_P_IP)) return XDP_PASS;

    /*
     * O cabeçalho IPv4 começa imediatamente após o cabeçalho Ethernet.
     */
    struct iphdr *ip = (void *)(eth + 1);

    /*
     * Repete a verificação de limites para provar que existe pelo menos um
     * cabeçalho IPv4 básico completo antes de acessar ip->saddr.
     */
    if ((void *)(ip + 1) > data_end) return XDP_PASS;

    /*
     * Copia o endereço IPv4 de origem para formar a chave da busca. O valor é
     * mantido na mesma ordem de bytes em que aparece no cabeçalho do pacote.
     * Por isso, o userspace precisa fornecer os bytes da chave na ordem
     * esperada pela Map.
     */
    __u32 src_ip = ip->saddr;

    /*
     * Procura src_ip na blacklist.
     *
     * Se a chave existir, bpf_map_lookup_elem() retorna um ponteiro para o
     * valor armazenado na Map. Se a chave não existir, retorna NULL. A busca
     * acontece no kernel para cada pacote IPv4 recebido.
     */
    __u32 *is_blocked = bpf_map_lookup_elem(&blacklist, &src_ip);

    /*
     * A primeira condição confirma que o ponteiro não é NULL. Somente depois
     * dessa verificação é seguro acessar *is_blocked.
     *
     * Quando a chave está presente e seu valor é 1, XDP_DROP encerra o
     * processamento e descarta o pacote antes que ele alcance as camadas
     * superiores da pilha de rede.
     */
    if (is_blocked && *is_blocked == 1) {
        return XDP_DROP;
    }

    /*
     * Libera todos os demais pacotes: não IPv4, origens ausentes da Map e
     * origens associadas a um valor diferente de 1.
     */
    return XDP_PASS;
}

/*
 * Informa ao kernel a licença do programa. A licença GPL permite o uso de
 * helpers disponibilizados somente a programas compatíveis com GPL.
 */
char _license[] SEC("license") = "GPL";
```

## 2. Como a Map representa a política

A Map separa o mecanismo de filtragem, implementado pelo programa XDP, da
política que determina quais origens estão bloqueadas.

| Elemento | Tipo | Papel no laboratório |
|---|---|---|
| Chave | `__u32` | Endereço IPv4 de origem |
| Valor | `__u32` | `1` indica que a origem deve ser bloqueada |
| Capacidade | 1.024 entradas | Quantidade máxima de chaves simultâneas |
| Tipo da Map | `BPF_MAP_TYPE_HASH` | Permite procurar o valor associado a uma chave |

O `bpftool` executado no userspace pode inserir ou remover entradas dessa Map.
O programa XDP consulta seu conteúdo atual a cada pacote; portanto, uma
alteração na blacklist produz efeito imediato e não exige recompilação.

## 3. A importância das verificações de limites

O programa recebe acesso direto aos bytes do pacote, mas esse acesso permanece
sujeito à análise do eBPF Verifier. Antes de ler um campo, o código precisa
demonstrar que os bytes correspondentes estão entre `data` e `data_end`.

As duas expressões abaixo cumprem essa função:

```c
if ((void *)(eth + 1) > data_end) return XDP_PASS;
if ((void *)(ip + 1) > data_end) return XDP_PASS;
```

Somente depois da primeira verificação o programa acessa `eth->h_proto`.
Somente depois da segunda ele acessa `ip->saddr`. Além de proteger o kernel
contra leituras inválidas, esse padrão fornece ao Verifier a prova necessária
para aceitar o programa.

## 4. Ordem de bytes do endereço IPv4

Os campos de protocolos de rede são armazenados em *network byte order*. O
programa copia `ip->saddr` diretamente para uma variável `__u32` e utiliza seus
bytes como chave, sem convertê-los para a ordem de bytes da CPU.

Para representar `10.0.1.2`, a chave inserida pelo laboratório é:

```text
0a 00 01 02
```

Isso corresponde exatamente aos quatro bytes do endereço no cabeçalho IPv4.
O valor `1`, por sua vez, é inserido como um `__u32` na ordem de bytes do
ambiente x86-64 utilizado no curso:

```text
01 00 00 00
```

## 5. O retorno de `bpf_map_lookup_elem`

O helper não retorna diretamente o número armazenado na Map. Seu resultado é
um ponteiro para o valor ou `NULL` quando a chave está ausente:

```c
__u32 *is_blocked = bpf_map_lookup_elem(&blacklist, &src_ip);
```

Por esse motivo, a condição verifica primeiro `is_blocked` e somente depois
acessa `*is_blocked`:

```c
if (is_blocked && *is_blocked == 1) {
    return XDP_DROP;
}
```

O operador `&&` utiliza avaliação de curto-circuito. Quando `is_blocked` é
`NULL`, a segunda parte não é executada, evitando a tentativa de acessar um
endereço inválido.

## 6. Significado das ações XDP

| Ação | Efeito neste programa |
|---|---|
| `XDP_DROP` | Descarta uma origem presente na Map com valor `1` |
| `XDP_PASS` | Permite que o pacote continue pela pilha de rede |

O programa adota uma política permissiva para tudo o que não corresponda
explicitamente a uma entrada bloqueada. Isso inclui pacotes não IPv4, pacotes
curtos ou incompletos e chaves ausentes da blacklist.

## 7. Limitações intencionais do exemplo

O firewall foi mantido pequeno para destacar o uso de eBPF Maps. Em uma
aplicação de produção, seria importante considerar:

- o tratamento desejado para pacotes malformados ou incompletos;
- suporte a IPv6, VLANs e outros formatos de quadro;
- valores de política mais expressivos que apenas `1`;
- contadores de pacotes e bytes bloqueados;
- sincronização e controle de acesso para atualizações da Map;
- fixação (*pinning*) da Map quando seu conteúdo precisar sobreviver ao
  ciclo de vida de uma instância do programa;
- telemetria para registrar decisões sem prejudicar o desempenho do caminho de
  pacotes.
