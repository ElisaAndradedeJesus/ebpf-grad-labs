#!/usr/bin/env bash
set -euo pipefail

if (( EUID != 0 )); then
    echo "Execute este laboratório com: sudo ./run_and_test.sh"
    exit 1
fi

LAB_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$LAB_DIR"

PIN_ROOT=/sys/fs/bpf/ebpf_lab1
ARCH_INCLUDE=/usr/include/$(gcc -print-multiarch)
VMLINUX_H="$LAB_DIR/vmlinux.h"

cleanup() {
    rm -rf "$PIN_ROOT"
    rm -f kprobe_exec.bpf.o lsm_block.bpf.o "$VMLINUX_H"
}
trap cleanup EXIT

echo "=== LAB 1: Kprobe vs. BPF LSM (WSL 2/x86-64) ==="

if [[ ! -r /sys/kernel/btf/vmlinux ]]; then
    echo "ERRO: /sys/kernel/btf/vmlinux não está disponível."
    echo "No PowerShell, execute 'wsl --update' e depois 'wsl --shutdown'."
    exit 1
fi

if ! mountpoint -q /sys/fs/bpf; then
    echo "Preparando o BPF filesystem em /sys/fs/bpf..."
    mkdir -p /sys/fs/bpf
    mount -t bpf bpf /sys/fs/bpf
fi

if ! mountpoint -q /sys/kernel/security; then
    echo "Preparando o securityfs em /sys/kernel/security..."
    mkdir -p /sys/kernel/security
    if ! mount -t securityfs securityfs /sys/kernel/security; then
        echo "AVISO: não foi possível montar securityfs; a verificação do BPF LSM pode ficar indisponível."
    fi
fi

echo "[1/4] Gerando vmlinux.h e compilando os programas..."
bpftool btf dump file /sys/kernel/btf/vmlinux format c > "$VMLINUX_H"

clang -O2 -g -target bpf -D__TARGET_ARCH_x86 \
    -I"$ARCH_INCLUDE" \
    -c kprobe_exec.bpf.c -o kprobe_exec.bpf.o

clang -O2 -g -target bpf -D__TARGET_ARCH_x86 \
    -I"$LAB_DIR" -I"$ARCH_INCLUDE" \
    -c lsm_block.bpf.c -o lsm_block.bpf.o

mkdir -p "$PIN_ROOT/kprobe"

echo "[2/4] Anexando o Kprobe a __x64_sys_execve..."
bpftool prog loadall kprobe_exec.bpf.o "$PIN_ROOT/kprobe" autoattach

echo "Kprobe carregado. Execute comandos em outro terminal e observe com:"
echo "  sudo cat /sys/kernel/tracing/trace_pipe"

echo "[3/4] Verificando a disponibilidade do BPF LSM..."
if [[ -r /sys/kernel/security/lsm ]] && grep -qw bpf /sys/kernel/security/lsm; then
    mkdir -p "$PIN_ROOT/lsm"
    bpftool prog loadall lsm_block.bpf.o "$PIN_ROOT/lsm" autoattach

    if curl --version &> /dev/null; then
        echo "FALHA: o curl foi executado mesmo com o BPF LSM carregado."
        exit 1
    else
        echo "SUCESSO: a execução do curl foi bloqueada pelo BPF LSM."
    fi
else
    echo "AVISO: BPF LSM não está ativo neste kernel; o teste de bloqueio será ignorado."
    echo "LSMs ativos: $(cat /sys/kernel/security/lsm 2>/dev/null || echo 'indisponível')"
fi

echo "[4/4] Pressione Enter para encerrar e remover os programas eBPF."
read -r
