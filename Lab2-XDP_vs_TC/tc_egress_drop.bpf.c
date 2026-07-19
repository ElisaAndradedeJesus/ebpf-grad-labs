#include <linux/bpf.h>
#include <linux/pkt_cls.h>
#include <linux/if_ether.h>
#include <linux/in.h>
#include <linux/ip.h>
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_endian.h>

SEC("classifier")
int tc_egress_filter(struct __sk_buff *skb)
{
    void *data_end = (void *)(long)skb->data_end;
    void *data     = (void *)(long)skb->data;

    struct ethhdr *eth = data;
    if ((void *)(eth + 1) > data_end) return TC_ACT_OK;
    if (bpf_ntohs(eth->h_proto) != ETH_P_IP) return TC_ACT_OK;

    struct iphdr *iph = (void *)(eth + 1);
    if ((void *)(iph + 1) > data_end) return TC_ACT_OK;

    if (iph->protocol == IPPROTO_TCP) {
        struct tcphdr {
            __be16 source;
            __be16 dest;
        } *tcp = (void *)iph + (iph->ihl * 4);

        if ((void *)(tcp + 1) > data_end) return TC_ACT_OK;

        if (tcp->dest == bpf_htons(80)) {
            return TC_ACT_SHOT; 
        }
    }
    return TC_ACT_OK;
}

char _license[] SEC("license") = "GPL";
