# Usa Bash porque o alvo run utiliza funcoes, trap e pipefail.
SHELL := /bin/bash

# Headers especificos da arquitetura, necessarios durante a compilacao eBPF.
ARCH_INCLUDE := /usr/include/$(shell gcc -print-multiarch 2>/dev/null)

# Nomes criados pelo Containerlab a partir de topology.yml.
LAB_NAME := ebpf-lab3
H1_CONTAINER := clab-$(LAB_NAME)-h1
H2_CONTAINER := clab-$(LAB_NAME)-h2
H3_CONTAINER := clab-$(LAB_NAME)-h3

.PHONY: help check build run destroy clean

help:
	@echo "Lab 3 - Firewall dinamico com eBPF Maps"
	@echo "  make check    verifica as dependencias"
	@echo "  make build    compila o programa XDP"
	@echo "  make run      executa e testa o laboratorio"
	@echo "  make destroy  destroi uma topologia remanescente"
	@echo "  make clean    destroi a topologia e remove objetos"

# Verifica ferramentas do host antes de criar containers ou carregar eBPF.
check:
	@command -v clang >/dev/null || { echo "ERRO: clang nao encontrado"; exit 1; }
	@command -v gcc >/dev/null || { echo "ERRO: gcc nao encontrado"; exit 1; }
	@command -v bpftool >/dev/null || { echo "ERRO: bpftool nao encontrado"; exit 1; }
	@command -v docker >/dev/null || { echo "ERRO: docker nao encontrado"; exit 1; }
	@command -v containerlab >/dev/null || { echo "ERRO: containerlab nao encontrado"; exit 1; }
	@command -v ip >/dev/null || { echo "ERRO: iproute2 nao encontrado"; exit 1; }
	@sudo docker info >/dev/null || { echo "ERRO: Docker daemon indisponivel"; exit 1; }
	@echo "Dependencias basicas do Lab 3 encontradas."

# Compila o firewall XDP e preserva informacoes BTF com -g.
build: check
	@echo "Compilando o firewall XDP..."
	@clang -O2 -g -target bpf -D__TARGET_ARCH_x86 -I"$(ARCH_INCLUDE)" \
		-c xdp_fw_map.bpf.c -o xdp_fw_map.o
	@echo "Programa eBPF compilado."

# O experimento cria tres namespaces. h1 recebe o XDP na interface ligada a h2;
# h2 representa o endereco que sera inserido na blacklist; h3 funciona como
# controle para demonstrar que outro cliente permanece alcançavel.
#
# A linha de base prova que h2 alcanca h1 com o map vazio. Depois, bpftool grava
# a chave IPv4 10.0.1.2 como bytes de rede (0a 00 01 02) e o valor inteiro 1 em
# little-endian (01 00 00 00). O teste final remove a chave sem recompilar o
# programa e confirma que a conectividade de h2 volta imediatamente.
run: build
	@set -euo pipefail; \
	cleanup() { \
		sudo containerlab destroy -t topology.yml --cleanup >/dev/null 2>&1 || true; \
		sudo rm -f /var/run/netns/h1 /var/run/netns/h2 /var/run/netns/h3; \
		rm -f xdp_fw_map.o; \
	}; \
	trap cleanup EXIT INT TERM; \
	echo "=== LAB 3: Firewall dinamico com eBPF Maps ==="; \
	sudo containerlab deploy -t topology.yml; \
	H1_PID=$$(sudo docker inspect -f '{{.State.Pid}}' "$(H1_CONTAINER)"); \
	H2_PID=$$(sudo docker inspect -f '{{.State.Pid}}' "$(H2_CONTAINER)"); \
	H3_PID=$$(sudo docker inspect -f '{{.State.Pid}}' "$(H3_CONTAINER)"); \
	sudo mkdir -p /var/run/netns; \
	sudo ln -sf "/proc/$$H1_PID/ns/net" /var/run/netns/h1; \
	sudo ln -sf "/proc/$$H2_PID/ns/net" /var/run/netns/h2; \
	sudo ln -sf "/proc/$$H3_PID/ns/net" /var/run/netns/h3; \
	sudo ip netns exec h1 ip addr replace 10.0.1.1/24 dev eth1; \
	sudo ip netns exec h2 ip addr replace 10.0.1.2/24 dev eth1; \
	sudo ip netns exec h1 ip addr replace 10.0.2.1/24 dev eth2; \
	sudo ip netns exec h3 ip addr replace 10.0.2.2/24 dev eth1; \
	sudo ip netns exec h1 ip link set eth1 up; \
	sudo ip netns exec h1 ip link set eth2 up; \
	sudo ip netns exec h2 ip link set eth1 up; \
	sudo ip netns exec h3 ip link set eth1 up; \
	echo "[1/4] Linha de base: h2 e h3 devem alcancar h1."; \
	sudo ip netns exec h2 ping -c 1 -W 2 10.0.1.1 >/dev/null; \
	sudo ip netns exec h3 ping -c 1 -W 2 10.0.2.1 >/dev/null; \
	echo "SUCESSO: conectividade inicial confirmada."; \
	sudo ip netns exec h1 ip link set dev eth1 xdp obj "$(CURDIR)/xdp_fw_map.o" sec xdp; \
	MAP_ID=$$(sudo bpftool map show | awk '/name blacklist / {gsub(":", "", $$1); id=$$1} END {print id}'); \
	test -n "$$MAP_ID" || { echo "ERRO: map blacklist nao encontrado"; exit 1; }; \
	echo "[2/4] Com XDP e map vazio: h2 ainda deve passar."; \
	sudo ip netns exec h2 ping -c 1 -W 2 10.0.1.1 >/dev/null; \
	echo "SUCESSO: map vazio nao bloqueou h2."; \
	echo "[3/4] Inserindo 10.0.1.2 na blacklist (map ID $$MAP_ID)."; \
	sudo bpftool map update id "$$MAP_ID" key hex 0a 00 01 02 value hex 01 00 00 00; \
	if sudo ip netns exec h2 ping -c 1 -W 2 10.0.1.1 >/dev/null 2>&1; then \
		echo "FALHA: h2 passou mesmo estando na blacklist."; \
		exit 1; \
	else \
		echo "SUCESSO: h2 foi bloqueado pela blacklist."; \
	fi; \
	sudo ip netns exec h3 ping -c 1 -W 2 10.0.2.1 >/dev/null; \
	echo "SUCESSO: h3 permaneceu permitido."; \
	echo "[4/4] Removendo 10.0.1.2 da blacklist."; \
	sudo bpftool map delete id "$$MAP_ID" key hex 0a 00 01 02; \
	sudo ip netns exec h2 ping -c 1 -W 2 10.0.1.1 >/dev/null; \
	echo "SUCESSO: h2 voltou a passar sem recompilar o programa."; \
	echo "Pressione Enter para destruir a topologia e encerrar."; \
	read -r

# Recupera o ambiente se uma execucao anterior tiver sido interrompida.
destroy:
	@sudo containerlab destroy -t topology.yml --cleanup || true
	@sudo rm -f /var/run/netns/h1 /var/run/netns/h2 /var/run/netns/h3

clean: destroy
	@rm -f xdp_fw_map.o
	@echo "Topologia e objetos do Lab 3 removidos."
