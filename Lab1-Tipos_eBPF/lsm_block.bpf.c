#include <vmlinux.h>
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_tracing.h>

#define EPERM 1 

SEC("lsm/bprm_check_security")
int BPF_PROG(restrict_execution, struct linux_binprm *bprm)
{
    char comm[128];
    bpf_probe_read_kernel_str(comm, sizeof(comm), bprm->filename);

    if (bpf_strncmp(comm, 13, "/usr/bin/curl") == 0) {
        char msg[] = "LSM: Execucao do curl bloqueada!\n";
        bpf_trace_printk(msg, sizeof(msg));
        return -EPERM; 
    }
    return 0;
}

char _license[] SEC("license") = "GPL";