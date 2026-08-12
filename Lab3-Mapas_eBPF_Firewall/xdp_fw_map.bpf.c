#include <linux/bpf.h>       /* Tipos, contexto e ações do eBPF/XDP. */
#include <linux/if_ether.h>  /* Estrutura do cabeçalho Ethernet. */
#include <linux/ip.h>        /* Estrutura do cabeçalho IPv4. */
#include <bpf/bpf_helpers.h> /* Macros SEC(), Maps e helpers eBPF. */
#include <bpf/bpf_endian.h>  /* Conversões de ordem de bytes. */

/*
 * Declara uma Hash Map chamada blacklist.
 *
 * A chave é um endereço IPv4 de origem. O valor indica se ele deve ser
 * bloqueado: neste laboratório, o valor 1 significa "bloquear".
 *
 * SEC(".maps") permite que o loader identifique a definição e solicite ao
 * kernel a criação da Map durante o carregamento do programa.
 */
struct {
    /* Tabela hash adequada para procurar uma decisão por endereço IPv4. */
    __uint(type, BPF_MAP_TYPE_HASH);

    /* Limita a blacklist a 1.024 chaves simultâneas. */
    __uint(max_entries, 1024);

    /* Cada chave e cada valor ocupam 32 bits. */
    __type(key, __u32);
    __type(value, __u32);
} blacklist SEC(".maps");

/*
 * SEC("xdp") declara um programa executado na entrada dos pacotes. O contexto
 * xdp_md fornece, entre outras informações, os limites da memória do pacote.
 */
SEC("xdp")
int xdp_firewall(struct xdp_md *ctx) {
    /*
     * ctx armazena os endereços como inteiros. As conversões produzem
     * ponteiros: data aponta para o primeiro byte do pacote e data_end para o
     * limite final de sua região de memória.
     */
    void *data_end = (void *)(long)ctx->data_end;
    void *data = (void *)(long)ctx->data;

    /* Interpreta os primeiros bytes como um cabeçalho Ethernet. */
    struct ethhdr *eth = data;

    /*
     * Antes de acessar os campos, prova ao eBPF Verifier que o cabeçalho
     * completo está dentro dos limites do pacote. eth + 1 aponta para o
     * primeiro byte depois de uma struct ethhdr completa.
     */
    if ((void *)(eth + 1) > data_end) return XDP_PASS;

    /*
     * Processa somente IPv4. h_proto usa ordem de bytes de rede; bpf_htons()
     * converte ETH_P_IP para o mesmo formato antes da comparação.
     */
    if (eth->h_proto != bpf_htons(ETH_P_IP)) return XDP_PASS;

    /* O cabeçalho IPv4 começa logo depois do cabeçalho Ethernet. */
    struct iphdr *ip = (void *)(eth + 1);

    /* Prova ao Verifier que existe um cabeçalho IPv4 básico completo. */
    if ((void *)(ip + 1) > data_end) return XDP_PASS;

    /*
     * Usa o endereço IPv4 de origem como chave, mantendo a ordem de bytes em
     * que ele aparece no pacote. O userspace deve inserir a chave nessa mesma
     * ordem para que ela seja encontrada.
     */
    __u32 src_ip = ip->saddr;

    /*
     * Procura a origem na blacklist. O helper retorna um ponteiro para o valor
     * armazenado ou NULL quando a chave não existe.
     */
    __u32 *is_blocked = bpf_map_lookup_elem(&blacklist, &src_ip);

    /*
     * Primeiro confirma que o ponteiro não é NULL. Somente então acessa seu
     * conteúdo. Quando o valor é 1, descarta o pacote antes que ele avance
     * pela pilha de rede.
     */
    if (is_blocked && *is_blocked == 1) {
        return XDP_DROP;
    }

    /* Libera pacotes cuja origem não esteja explicitamente bloqueada. */
    return XDP_PASS;
}

/* Informa ao kernel que o programa utiliza uma licença compatível com GPL. */
char _license[] SEC("license") = "GPL";
