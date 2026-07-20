# Usa Bash para executar as receitas. O alvo run utiliza recursos como funcoes,
# trap e pipefail, que nao fazem parte de todos os shells POSIX.
SHELL := /bin/bash

# gcc -print-multiarch descobre o diretorio dos headers da arquitetura atual.
# Em x86-64, por exemplo, o resultado costuma ser /usr/include/x86_64-linux-gnu.
# Esse caminho e necessario para que o Clang encontre headers como asm/types.h.
ARCH_INCLUDE := /usr/include/$(shell gcc -print-multiarch 2>/dev/null)

# Diretorio do bpffs no qual programas e links do laboratorio serao fixados.
# O pinning mantem referencias aos objetos eBPF enquanto o teste esta ativo.
PIN_ROOT := /sys/fs/bpf/ebpf_lab1

# Estes nomes representam acoes, e nao arquivos que devem ser gerados.
# A declaracao PHONY garante que os alvos sejam executados mesmo se existir um
# arquivo chamado help, check, mounts, build, run ou clean no diretorio.
.PHONY: help check mounts build run clean

# Exibe os comandos disponiveis sem preparar ou modificar o ambiente.
help:
	@echo "Lab 1 - Kprobe e BPF LSM"
	@echo "  make check   verifica as dependencias do laboratorio"
	@echo "  make mounts  prepara bpffs e securityfs"
	@echo "  make build   gera vmlinux.h e compila os programas"
	@echo "  make run     prepara, compila e executa o laboratorio"
	@echo "  make clean   remove programas e arquivos gerados"

# Verifica primeiro as ferramentas usadas na compilacao e na inspecao eBPF.
# command -v termina com erro quando um executavel nao esta no PATH.
# A ultima verificacao confirma a disponibilidade do BTF do kernel, necessario
# para gerar o header vmlinux.h utilizado pelo programa BPF LSM.
check:
	@command -v clang >/dev/null || { \
		echo "ERRO: Clang nao foi encontrado; sem ele os programas eBPF nao podem ser compilados."; \
		echo "Instale com: sudo apt update && sudo apt install -y clang llvm"; \
		echo "Depois, execute novamente: make check"; exit 1; }
	@command -v gcc >/dev/null || { \
		echo "ERRO: GCC nao foi encontrado; ele e usado para descobrir os headers da arquitetura."; \
		echo "Instale com: sudo apt install -y build-essential"; \
		echo "Depois, execute novamente: make check"; exit 1; }
	@command -v bpftool >/dev/null || { \
		echo "ERRO: bpftool nao foi encontrado; ele e necessario para gerar vmlinux.h e carregar eBPF."; \
		echo "Instale com: sudo apt install -y bpftool"; \
		echo "Consulte tambem a preparacao do ambiente no README principal."; exit 1; }
	@command -v mountpoint >/dev/null || { \
		echo "ERRO: mountpoint nao foi encontrado; nao e possivel verificar bpffs e securityfs."; \
		echo "Instale com: sudo apt install -y util-linux"; \
		echo "Depois, execute novamente: make check"; exit 1; }
	@test -r /sys/kernel/btf/vmlinux || { \
		echo "ERRO: /sys/kernel/btf/vmlinux nao esta disponivel."; \
		echo "No PowerShell, execute 'wsl --update' e depois 'wsl --shutdown'."; \
		exit 1; \
	}
	@echo "Dependencias basicas do Lab 1 encontradas."

# Prepara os dois filesystems virtuais usados pelo laboratorio:
#
# - bpffs: permite fixar programas, links e maps eBPF em /sys/fs/bpf;
# - securityfs: expoe informacoes dos Linux Security Modules em
#   /sys/kernel/security, incluindo a lista de LSMs ativos.
#
# mountpoint evita montar novamente um filesystem que ja esteja pronto.
# A falha de securityfs gera apenas um aviso porque o Kprobe pode funcionar sem
# ele; nesse caso, somente o teste opcional do BPF LSM fica indisponivel.
mounts:
	@if ! mountpoint -q /sys/fs/bpf; then \
		echo "Preparando o BPF filesystem em /sys/fs/bpf..."; \
		sudo mkdir -p /sys/fs/bpf; \
		sudo mount -t bpf bpf /sys/fs/bpf; \
	fi
	@if ! mountpoint -q /sys/kernel/security; then \
		echo "Preparando o securityfs em /sys/kernel/security..."; \
		sudo mkdir -p /sys/kernel/security; \
		if ! sudo mount -t securityfs securityfs /sys/kernel/security; then \
			echo "AVISO: nao foi possivel montar securityfs; a verificacao do BPF LSM pode ficar indisponivel."; \
		fi; \
	fi

# O alvo build depende de check: as dependencias sao verificadas antes da
# compilacao. Primeiro, bpftool converte o BTF do kernel em vmlinux.h. Depois,
# Clang gera bytecode eBPF (-target bpf) para cada programa do laboratorio.
#
# -D__TARGET_ARCH_x86 informa a arquitetura esperada pelas macros da libbpf.
# -O2 gera codigo adequado ao verifier e -g inclui informacoes BTF de depuracao.
build: check
	@echo "Gerando vmlinux.h e compilando os programas..."
	@bpftool btf dump file /sys/kernel/btf/vmlinux format c > vmlinux.h
	@clang -O2 -g -target bpf -D__TARGET_ARCH_x86 \
		-I"$(ARCH_INCLUDE)" \
		-c kprobe_exec.bpf.c -o kprobe_exec.bpf.o || { \
			echo "ERRO: falha ao compilar kprobe_exec.bpf.c."; \
			echo "Leia o diagnostico do Clang acima e confirme os pacotes clang, libbpf-dev e headers."; \
			exit 1; }
	@clang -O2 -g -target bpf -D__TARGET_ARCH_x86 \
		-I"$(CURDIR)" -I"$(ARCH_INCLUDE)" \
		-c lsm_block.bpf.c -o lsm_block.bpf.o || { \
			echo "ERRO: falha ao compilar lsm_block.bpf.c."; \
			echo "Leia o diagnostico do Clang acima e confirme se vmlinux.h foi gerado corretamente."; \
			exit 1; }
	@echo "Programas eBPF compilados."

# Fluxo completo do experimento. As dependencias do alvo fazem com que o Make
# execute check, mounts e build antes desta receita.
#
# set -euo pipefail interrompe a execucao ao encontrar erros, variaveis nao
# definidas ou falhas escondidas em pipelines. A funcao cleanup remove os pins e
# objetos gerados. trap garante a limpeza tanto no encerramento normal quanto em
# interrupcoes por Ctrl+C ou erro.
#
# bpftool prog loadall carrega o objeto no kernel. A opcao autoattach interpreta
# SEC("kprobe/__x64_sys_execve") e cria o link entre o programa e o hook.
# Enquanto o comando aguarda Enter, esse link permanece fixado no bpffs.
#
# Em seguida, /sys/kernel/security/lsm e consultado. O programa LSM so e
# carregado quando "bpf" aparece entre os LSMs ativos. Se estiver disponivel,
# curl --version funciona como teste: o retorno do programa eBPF deve negar a
# execucao. Se BPF LSM nao estiver ativo, o Kprobe continua sendo testavel.
run: check mounts build
	@set -Eeuo pipefail; \
	cleanup() { \
		sudo rm -rf "$(PIN_ROOT)" || true; \
		rm -f kprobe_exec.bpf.o lsm_block.bpf.o vmlinux.h; \
	}; \
	on_error() { \
		status=$$?; \
		echo "ERRO: o Lab 1 foi interrompido durante a preparacao ou o carregamento do programa eBPF."; \
		echo "Leia a mensagem imediatamente acima para identificar a causa."; \
		echo "O ambiente sera limpo automaticamente. Consulte 'Solucao de problemas' no README do Lab 1."; \
		exit $$status; \
	}; \
	trap cleanup EXIT INT TERM; \
	trap on_error ERR; \
	echo "=== LAB 1: Kprobe vs. BPF LSM (WSL 2/x86-64) ==="; \
	sudo mkdir -p "$(PIN_ROOT)/kprobe"; \
	echo "Anexando o Kprobe a __x64_sys_execve..."; \
	sudo bpftool prog loadall kprobe_exec.bpf.o "$(PIN_ROOT)/kprobe" autoattach; \
	echo "Kprobe carregado. Em outro terminal, observe com:"; \
	echo "  sudo cat /sys/kernel/tracing/trace_pipe"; \
	echo "Verificando a disponibilidade do BPF LSM..."; \
	if sudo test -r /sys/kernel/security/lsm && sudo grep -qw bpf /sys/kernel/security/lsm; then \
		sudo mkdir -p "$(PIN_ROOT)/lsm"; \
		sudo bpftool prog loadall lsm_block.bpf.o "$(PIN_ROOT)/lsm" autoattach; \
		if curl --version >/dev/null 2>&1; then \
			echo "FALHA: o curl foi executado mesmo com o BPF LSM carregado."; \
			exit 1; \
		else \
			echo "SUCESSO: a execucao do curl foi bloqueada pelo BPF LSM."; \
		fi; \
	else \
		echo "AVISO: BPF LSM nao esta ativo neste kernel; o teste de bloqueio sera ignorado."; \
		echo "LSMs ativos: $$(sudo cat /sys/kernel/security/lsm 2>/dev/null || echo 'indisponivel')"; \
	fi; \
	echo "Pressione Enter para encerrar e remover os programas eBPF."; \
	read -r

# Permite recuperar o ambiente manualmente se uma execucao anterior tiver sido
# interrompida. Remove os pins do kernel e os artefatos locais de compilacao.
clean:
	@sudo rm -rf "$(PIN_ROOT)"
	@rm -f kprobe_exec.bpf.o lsm_block.bpf.o vmlinux.h
	@echo "Programas e arquivos gerados pelo Lab 1 removidos."
