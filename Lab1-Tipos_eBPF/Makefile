.PHONY: help check run clean

help:
	@echo "Lab 1 - Kprobe e BPF LSM"
	@echo "  make check  verifica as dependencias do laboratorio"
	@echo "  make run    prepara, compila e executa o laboratorio"
	@echo "  make clean  remove objetos eBPF e arquivos gerados"

check:
	@command -v clang >/dev/null || { echo "ERRO: clang nao encontrado"; exit 1; }
	@command -v gcc >/dev/null || { echo "ERRO: gcc nao encontrado"; exit 1; }
	@command -v bpftool >/dev/null || { echo "ERRO: bpftool nao encontrado"; exit 1; }
	@test -r /sys/kernel/btf/vmlinux || { echo "ERRO: /sys/kernel/btf/vmlinux indisponivel"; exit 1; }
	@echo "Dependencias basicas do Lab 1 encontradas."

run: check
	@sudo bash ./run_and_test.sh

clean:
	@sudo rm -rf /sys/fs/bpf/ebpf_lab1
	@rm -f -- kprobe_exec.bpf.o lsm_block.bpf.o vmlinux.h
	@echo "Arquivos gerados pelo Lab 1 removidos."
