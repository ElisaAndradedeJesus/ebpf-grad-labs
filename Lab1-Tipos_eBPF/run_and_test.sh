#!/bin/bash
set -e

echo "=== LAB 1: Kprobe vs LSM ==="
mkdir -p /sys/fs/bpf
rm -f /sys/fs/bpf/trace_exec /sys/fs/bpf/lsm_block
echo "" > /sys/kernel/debug/tracing/trace_pipe

echo "[1/4] Compilando..."
clang -O2 -target bpf -c kprobe_exec.bpf.c -o kprobe_exec.bpf.o
clang -O2 -target bpf -c lsm_block.bpf.c -o lsm_block.bpf.o

echo "[2/4] KPROBE: Monitorando execucoes..."
bpftool prog load kprobe_exec.bpf.o /sys/fs/bpf/trace_exec
bpftool prog attach pinned /sys/fs/bpf/trace_exec kprobe sys_execve
ls > /dev/null
cat /sys/kernel/debug/tracing/trace_pipe | head -n 3 | grep KPROBE || echo "Sem logs"

echo -e "\n[3/4] LSM: Bloqueando comando 'curl'..."
bpftool prog load lsm_block.bpf.o /sys/fs/bpf/lsm_block type lsm
bpftool prog attach pinned /sys/fs/bpf/lsm_block lsm bprm_check_security

if curl --version &> /dev/null; then
    echo "❌ FALHA: O curl rodou!"
else
    echo "✅ SUCESSO: Execução do curl bloqueada!"
fi

echo "[4/4] Limpando..."
bpftool prog detach pinned /sys/fs/bpf/trace_exec kprobe sys_execve
bpftool prog detach pinned /sys/fs/bpf/lsm_block lsm bprm_check_security
rm -f /sys/fs/bpf/trace_exec /sys/fs/bpf/lsm_block *.o