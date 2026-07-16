#include <linux/bpf.h>
#include <bpf/bpf_helpers.h>

SEC("kprobe/sys_execve")
int trace_exec(void *ctx)
{
    char comm[16];
    bpf_get_current_comm(&comm, sizeof(comm));
    
    char msg[] = "KPROBE: Processo '%s' executado!\n";
    bpf_trace_printk(msg, sizeof(msg), comm);
    
    return 0;
}

char _license[] SEC("license") = "GPL";