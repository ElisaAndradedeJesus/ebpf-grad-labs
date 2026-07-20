# Usa Bash porque os alvos setup e test utilizam funcoes, trap e pipefail.
SHELL := /bin/bash

# Headers especificos da arquitetura, necessarios para asm/types.h.
ARCH_INCLUDE := /usr/include/$(shell gcc -print-multiarch 2>/dev/null)

# Nomes criados pelo Containerlab a partir de topology.yml.
LAB_NAME := ebpf-lab2
H1_CONTAINER := clab-$(LAB_NAME)-h1
H2_CONTAINER := clab-$(LAB_NAME)-h2

# Rede exclusiva do enlace experimental h1--h2. Ela deve ser diferente da
# rede administrativa criada pelo Containerlab (normalmente 172.20.20.0/24),
# para que os testes atravessem eth1 e alcancem os hooks XDP e TC.
H1_LAB_IP := 10.10.12.1
H2_LAB_IP := 10.10.12.2
LAB_PREFIX := 24

.PHONY: help check build setup test destroy clean

# Mostra a interface publica do laboratorio.
help:
	@echo "Lab 2 - XDP vs. TC"
	@echo "  make check    verifica as dependencias"
	@echo "  make build    compila os programas eBPF"
	@echo "  make setup    compila e monta a topologia"
	@echo "  make test     executa os testes na topologia pronta"
	@echo "  make destroy  destroi uma topologia remanescente"
	@echo "  make clean    destroi a topologia e remove objetos"

# Verifica ferramentas do host antes de criar containers ou alterar a rede.
check:
	@command -v clang >/dev/null || { \
		echo "ERRO: Clang nao foi encontrado; sem ele XDP e TC nao podem ser compilados."; \
		echo "Instale com: sudo apt update && sudo apt install -y clang llvm"; \
		echo "Depois, execute novamente: make check"; exit 1; }
	@command -v gcc >/dev/null || { \
		echo "ERRO: GCC nao foi encontrado; ele e usado para localizar os headers da arquitetura."; \
		echo "Instale com: sudo apt install -y build-essential"; \
		echo "Depois, execute novamente: make check"; exit 1; }
	@command -v docker >/dev/null || { \
		echo "ERRO: Docker nao foi encontrado; o Containerlab depende dele para criar os hosts."; \
		echo "Volte ao README principal e conclua a secao 'Instalar e testar o Docker'."; \
		echo "Instalacao usada pelo curso:"; \
		echo "  curl -fsSL https://get.docker.com -o get-docker.sh"; \
		echo "  sudo sh get-docker.sh"; exit 1; }
	@command -v containerlab >/dev/null || { \
		echo "ERRO: Containerlab nao foi encontrado; a topologia h1--h2 nao pode ser criada."; \
		echo "Volte ao README principal e conclua a secao 'Instalar e testar o Containerlab'."; \
		echo "Instale com: bash -c \"\$$(curl -sL https://get.containerlab.dev)\""; \
		echo "Depois, confirme com: containerlab version"; exit 1; }
	@command -v ip >/dev/null || { \
		echo "ERRO: o comando ip nao foi encontrado; os namespaces nao podem ser configurados."; \
		echo "Instale com: sudo apt install -y iproute2"; exit 1; }
	@command -v tc >/dev/null || { \
		echo "ERRO: o comando tc nao foi encontrado; o filtro TC egress nao pode ser anexado."; \
		echo "Instale com: sudo apt install -y iproute2"; exit 1; }
	@sudo docker info >/dev/null 2>&1 || { \
		echo "ERRO: Docker esta instalado, mas o daemon nao esta em execucao ou nao respondeu."; \
		echo "Inicie com: sudo service docker start"; \
		echo "Teste com: sudo docker info"; \
		echo "Se continuar falhando, consulte 'Docker daemon nao esta rodando' no README principal."; exit 1; }
	@echo "Dependencias basicas do Lab 2 encontradas."

# Compila um programa XDP e um classificador TC para bytecode eBPF.
# -O2 facilita a verificacao pelo verifier e -target bpf seleciona o backend BPF.
build: check
	@echo "Compilando os programas XDP e TC..."
	@clang -O2 -g -target bpf -D__TARGET_ARCH_x86 -I"$(ARCH_INCLUDE)" \
		-c xdp_drop_icmp.bpf.c -o xdp.o || { \
			echo "ERRO: falha ao compilar o programa XDP."; \
			echo "Leia o diagnostico do Clang acima e confirme clang, libbpf-dev e os headers."; exit 1; }
	@clang -O2 -g -target bpf -D__TARGET_ARCH_x86 -I"$(ARCH_INCLUDE)" \
		-c tc_egress_drop.bpf.c -o tc.o || { \
			echo "ERRO: falha ao compilar o programa TC."; \
			echo "Leia o diagnostico do Clang acima e confirme clang, libbpf-dev e os headers."; exit 1; }
	@echo "Programas eBPF compilados."

# Monta a topologia e configura apenas o ambiente. Nenhum teste e executado e
# nenhum programa eBPF e anexado nesta etapa.
setup: build
	@set -Eeuo pipefail; \
	cleanup() { \
		sudo containerlab destroy -t topology.yml --cleanup >/dev/null 2>&1 || true; \
		sudo rm -f /var/run/netns/h1 /var/run/netns/h2; \
	}; \
	on_error() { \
		status=$$?; \
		echo "ERRO: nao foi possivel preparar a topologia do Lab 2."; \
		echo "Leia a mensagem imediatamente acima: ela indica a etapa ou comando que falhou."; \
		echo "A preparacao incompleta sera removida automaticamente."; \
		cleanup; \
		exit $$status; \
	}; \
	trap cleanup INT TERM; \
	trap on_error ERR; \
	sudo containerlab destroy -t topology.yml --cleanup >/dev/null 2>&1 || true; \
	sudo containerlab deploy -t topology.yml; \
	H1_PID=$$(sudo docker inspect -f '{{.State.Pid}}' "$(H1_CONTAINER)"); \
	H2_PID=$$(sudo docker inspect -f '{{.State.Pid}}' "$(H2_CONTAINER)"); \
	sudo mkdir -p /var/run/netns; \
	sudo ln -sf "/proc/$$H1_PID/ns/net" /var/run/netns/h1; \
	sudo ln -sf "/proc/$$H2_PID/ns/net" /var/run/netns/h2; \
	sudo ip netns exec h1 ip addr replace "$(H1_LAB_IP)/$(LAB_PREFIX)" dev eth1; \
	sudo ip netns exec h2 ip addr replace "$(H2_LAB_IP)/$(LAB_PREFIX)" dev eth1; \
	sudo ip netns exec h1 ip link set eth1 up; \
	sudo ip netns exec h2 ip link set eth1 up; \
	echo "Ambiente do Lab 2 preparado."; \
	echo "Topologia ativa: h1 ($(H1_LAB_IP)) <-> h2 ($(H2_LAB_IP))"; \
	echo "Execute os testes com: make test"

# Executa somente os testes. A linha de base e medida antes de cada filtro para
# evitar falsos positivos. A topologia permanece ativa ao final para inspecao.
test:
	@test -f xdp.o -a -f tc.o -a -e /var/run/netns/h1 -a -e /var/run/netns/h2 || { \
		echo "ERRO: o ambiente do Lab 2 nao esta preparado."; \
		echo "Execute primeiro: make setup"; exit 1; }
	@set -Eeuo pipefail; \
	on_error() { \
		status=$$?; \
		echo "ERRO: o Lab 2 foi interrompido antes de concluir os testes de XDP e TC."; \
		echo "Leia a mensagem imediatamente acima: ela indica a etapa que falhou."; \
		echo "A topologia foi mantida para inspecao. Remova-a com: make clean"; \
		exit $$status; \
	}; \
	trap on_error ERR; \
	echo "=== LAB 2: XDP ingress vs. TC egress ==="; \
	sudo ip netns exec h1 ip link set dev eth1 xdp off >/dev/null 2>&1 || true; \
	sudo ip netns exec h2 tc qdisc del dev eth1 clsact >/dev/null 2>&1 || true; \
	echo "[XDP 1/2] Linha de base: ICMP deve funcionar antes do filtro."; \
	if ! sudo ip netns exec h2 ping -c 1 -W 2 "$(H1_LAB_IP)" >/dev/null; then \
		echo "ERRO: h2 nao conseguiu pingar h1 antes do XDP."; \
		echo "A linha de base falhou; verifique a topologia, os IPs e a instalacao de iputils-ping nos containers."; \
		exit 1; \
	fi; \
	echo "SUCESSO: ping funcionou sem XDP."; \
	echo "Anexando XDP em modo generico, compativel com a interface veth do Containerlab."; \
	if ! sudo ip netns exec h1 ip link set dev eth1 xdpgeneric obj "$(CURDIR)/xdp.o" sec xdp; then \
		echo "ERRO: nao foi possivel anexar o programa XDP generico a eth1 de h1."; \
		echo "O modo generico e usado porque pares veth no WSL podem rejeitar XDP nativo por causa do MTU do peer."; \
		echo "Verifique o suporte do kernel com: sudo bpftool feature probe kernel"; \
		exit 1; \
	fi; \
	echo "[XDP 2/2] Com XDP: ICMP deve ser descartado no ingresso de h1."; \
	if sudo ip netns exec h2 ping -c 1 -W 2 "$(H1_LAB_IP)" >/dev/null 2>&1; then \
		echo "FALHA: ping passou mesmo com XDP."; \
		exit 1; \
	else \
		echo "SUCESSO: XDP bloqueou o ICMP no ingresso de h1."; \
	fi; \
	sudo ip netns exec h1 sh -c 'nohup nc -lk -p 80 >/tmp/lab2-nc.log 2>&1 &'; \
	sleep 1; \
	echo "[TC 1/2] Linha de base: TCP/80 deve funcionar antes do filtro."; \
	if ! sudo ip netns exec h2 nc -z -w 2 "$(H1_LAB_IP)" 80; then \
		echo "ERRO: a conexao TCP/80 falhou antes do filtro TC."; \
		echo "Verifique se netcat-openbsd foi instalado no container h1 e se o servidor nc iniciou."; \
		exit 1; \
	fi; \
	echo "SUCESSO: conexao TCP/80 funcionou sem TC."; \
	sudo ip netns exec h2 tc qdisc replace dev eth1 clsact; \
	sudo ip netns exec h2 tc filter replace dev eth1 egress bpf da obj "$(CURDIR)/tc.o" sec classifier; \
	echo "[TC 2/2] Com TC: TCP/80 deve ser descartado na saida de h2."; \
	if sudo ip netns exec h2 nc -z -w 2 "$(H1_LAB_IP)" 80; then \
		echo "FALHA: conexao TCP/80 passou mesmo com TC."; \
		exit 1; \
	else \
		echo "SUCESSO: TC bloqueou TCP/80 no egress de h2."; \
	fi; \
	echo "Todos os testes do Lab 2 foram concluidos."; \
	echo "A topologia continua ativa para inspecao. Ao terminar, execute: make clean"

# Recupera o ambiente caso uma execucao anterior tenha sido interrompida.
destroy:
	@sudo containerlab destroy -t topology.yml --cleanup || true
	@sudo rm -f /var/run/netns/h1 /var/run/netns/h2

clean: destroy
	@rm -f xdp.o tc.o
	@echo "Topologia e objetos do Lab 2 removidos."
