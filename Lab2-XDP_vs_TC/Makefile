# Usa Bash porque o alvo run utiliza funcoes, trap e pipefail.
SHELL := /bin/bash

# Headers especificos da arquitetura, necessarios para asm/types.h.
ARCH_INCLUDE := /usr/include/$(shell gcc -print-multiarch 2>/dev/null)

# Nomes criados pelo Containerlab a partir de topology.yml.
LAB_NAME := ebpf-lab2
H1_CONTAINER := clab-$(LAB_NAME)-h1
H2_CONTAINER := clab-$(LAB_NAME)-h2

.PHONY: help check build run destroy clean

# Mostra a interface publica do laboratorio.
help:
	@echo "Lab 2 - XDP vs. TC"
	@echo "  make check    verifica as dependencias"
	@echo "  make build    compila os programas eBPF"
	@echo "  make run      executa e testa o laboratorio"
	@echo "  make destroy  destroi uma topologia remanescente"
	@echo "  make clean    destroi a topologia e remove objetos"

# Verifica ferramentas do host antes de criar containers ou alterar a rede.
check:
	@command -v clang >/dev/null || { echo "ERRO: clang nao encontrado"; exit 1; }
	@command -v gcc >/dev/null || { echo "ERRO: gcc nao encontrado"; exit 1; }
	@command -v docker >/dev/null || { echo "ERRO: docker nao encontrado"; exit 1; }
	@command -v containerlab >/dev/null || { echo "ERRO: containerlab nao encontrado"; exit 1; }
	@command -v ip >/dev/null || { echo "ERRO: iproute2 nao encontrado"; exit 1; }
	@command -v tc >/dev/null || { echo "ERRO: tc nao encontrado"; exit 1; }
	@sudo docker info >/dev/null || { echo "ERRO: Docker daemon indisponivel"; exit 1; }
	@echo "Dependencias basicas do Lab 2 encontradas."

# Compila um programa XDP e um classificador TC para bytecode eBPF.
# -O2 facilita a verificacao pelo verifier e -target bpf seleciona o backend BPF.
build: check
	@echo "Compilando os programas XDP e TC..."
	@clang -O2 -g -target bpf -D__TARGET_ARCH_x86 -I"$(ARCH_INCLUDE)" \
		-c xdp_drop_icmp.bpf.c -o xdp.o
	@clang -O2 -g -target bpf -D__TARGET_ARCH_x86 -I"$(ARCH_INCLUDE)" \
		-c tc_egress_drop.bpf.c -o tc.o
	@echo "Programas eBPF compilados."

# Executa o experimento completo em uma unica receita para que trap consiga
# destruir a topologia mesmo quando um teste falhar ou o usuario pressionar
# Ctrl+C. Os PIDs dos containers sao ligados a /var/run/netns; assim, ip e tc
# podem operar diretamente nos namespaces criados pelo Containerlab.
#
# O teste sempre mede uma linha de base antes do filtro. Isso evita falsos
# positivos: uma falha so conta como bloqueio quando a mesma comunicacao havia
# funcionado antes de anexar o programa eBPF.
run: build
	@set -euo pipefail; \
	cleanup() { \
		sudo containerlab destroy -t topology.yml --cleanup >/dev/null 2>&1 || true; \
		sudo rm -f /var/run/netns/h1 /var/run/netns/h2; \
		rm -f xdp.o tc.o; \
	}; \
	trap cleanup EXIT INT TERM; \
	echo "=== LAB 2: XDP ingress vs. TC egress ==="; \
	sudo containerlab deploy -t topology.yml; \
	H1_PID=$$(sudo docker inspect -f '{{.State.Pid}}' "$(H1_CONTAINER)"); \
	H2_PID=$$(sudo docker inspect -f '{{.State.Pid}}' "$(H2_CONTAINER)"); \
	sudo mkdir -p /var/run/netns; \
	sudo ln -sf "/proc/$$H1_PID/ns/net" /var/run/netns/h1; \
	sudo ln -sf "/proc/$$H2_PID/ns/net" /var/run/netns/h2; \
	sudo ip netns exec h1 ip addr replace 172.20.20.1/24 dev eth1; \
	sudo ip netns exec h2 ip addr replace 172.20.20.2/24 dev eth1; \
	sudo ip netns exec h1 ip link set eth1 up; \
	sudo ip netns exec h2 ip link set eth1 up; \
	echo "[XDP 1/2] Linha de base: ICMP deve funcionar antes do filtro."; \
	sudo ip netns exec h2 ping -c 1 -W 2 172.20.20.1 >/dev/null; \
	echo "SUCESSO: ping funcionou sem XDP."; \
	sudo ip netns exec h1 ip link set dev eth1 xdp obj "$(CURDIR)/xdp.o" sec xdp; \
	echo "[XDP 2/2] Com XDP: ICMP deve ser descartado no ingresso de h1."; \
	if sudo ip netns exec h2 ping -c 1 -W 2 172.20.20.1 >/dev/null 2>&1; then \
		echo "FALHA: ping passou mesmo com XDP."; \
		exit 1; \
	else \
		echo "SUCESSO: XDP bloqueou o ICMP no ingresso de h1."; \
	fi; \
	sudo ip netns exec h1 sh -c 'nohup nc -lk -p 80 >/tmp/lab2-nc.log 2>&1 &'; \
	sleep 1; \
	echo "[TC 1/2] Linha de base: TCP/80 deve funcionar antes do filtro."; \
	sudo ip netns exec h2 nc -z -w 2 172.20.20.1 80; \
	echo "SUCESSO: conexao TCP/80 funcionou sem TC."; \
	sudo ip netns exec h2 tc qdisc replace dev eth1 clsact; \
	sudo ip netns exec h2 tc filter replace dev eth1 egress bpf da obj "$(CURDIR)/tc.o" sec classifier; \
	echo "[TC 2/2] Com TC: TCP/80 deve ser descartado na saida de h2."; \
	if sudo ip netns exec h2 nc -z -w 2 172.20.20.1 80; then \
		echo "FALHA: conexao TCP/80 passou mesmo com TC."; \
		exit 1; \
	else \
		echo "SUCESSO: TC bloqueou TCP/80 no egress de h2."; \
	fi; \
	echo "Pressione Enter para destruir a topologia e encerrar."; \
	read -r

# Recupera o ambiente caso uma execucao anterior tenha sido interrompida.
destroy:
	@sudo containerlab destroy -t topology.yml --cleanup || true
	@sudo rm -f /var/run/netns/h1 /var/run/netns/h2

clean: destroy
	@rm -f xdp.o tc.o
	@echo "Topologia e objetos do Lab 2 removidos."
