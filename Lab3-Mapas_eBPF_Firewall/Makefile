# Usa Bash porque os alvos utilizam funcoes, traps e pipefail.
SHELL := /bin/bash

# Headers da arquitetura usados pelo Clang durante a compilacao eBPF.
ARCH_INCLUDE := /usr/include/$(shell gcc -print-multiarch 2>/dev/null)

# Nomes criados pelo Containerlab a partir de topology.yml.
LAB_NAME := ebpf-lab3
H1_CONTAINER := clab-$(LAB_NAME)-h1
H2_CONTAINER := clab-$(LAB_NAME)-h2

# O ID e salvo fora do repositorio para que as etapas seguintes atualizem
# exatamente o map criado por este laboratorio, mesmo que existam outros maps
# chamados "blacklist" no computador.
MAP_ID_FILE := /tmp/ebpf-lab3-map-id

.PHONY: help check build setup verify-env test-baseline test-empty-map test-block test-unblock detach-xdp destroy clean

help:
	@echo "Lab 3 - Firewall dinamico com eBPF Maps"
	@echo "  make check           verifica as dependencias"
	@echo "  make build           compila o programa XDP"
	@echo "  make setup           compila e monta a topologia"
	@echo "  make test-baseline   testa os dois enderecos sem XDP"
	@echo "  make test-empty-map  anexa XDP e testa o map vazio"
	@echo "  make test-block      bloqueia um endereco e preserva o controle"
	@echo "  make test-unblock    remove o endereco da blacklist"
	@echo "  make detach-xdp      desanexa o programa XDP"
	@echo "  make clean           destroi a topologia e remove os objetos"

# Verifica as ferramentas antes de criar containers ou carregar eBPF.
check:
	@command -v clang >/dev/null || { \
		echo "ERRO: Clang nao foi encontrado; o programa XDP nao pode ser compilado."; \
		echo "Instale com: sudo apt update && sudo apt install -y clang llvm"; exit 1; }
	@command -v gcc >/dev/null || { \
		echo "ERRO: GCC nao foi encontrado; ele e usado para localizar os headers."; \
		echo "Instale com: sudo apt install -y build-essential"; exit 1; }
	@command -v bpftool >/dev/null || { \
		echo "ERRO: bpftool nao foi encontrado; a blacklist nao pode ser atualizada."; \
		echo "Instale com: sudo apt install -y bpftool"; \
		echo "Consulte tambem a preparacao do ambiente no README principal."; exit 1; }
	@command -v docker >/dev/null || { \
		echo "ERRO: Docker nao foi encontrado; o Containerlab depende dele."; \
		echo "Volte ao README principal e conclua a instalacao do Docker."; exit 1; }
	@command -v containerlab >/dev/null || { \
		echo "ERRO: Containerlab nao foi encontrado; a topologia nao pode ser criada."; \
		echo "Volte ao README principal ou instale com:"; \
		echo "  bash -c \"\$$(curl -sL https://get.containerlab.dev)\""; exit 1; }
	@command -v ip >/dev/null || { \
		echo "ERRO: o comando ip nao foi encontrado."; \
		echo "Instale com: sudo apt install -y iproute2"; exit 1; }
	@sudo docker info >/dev/null 2>&1 || { \
		echo "ERRO: Docker esta instalado, mas o daemon nao respondeu."; \
		echo "Inicie com: sudo service docker start"; \
		echo "Depois confirme com: sudo docker info"; exit 1; }
	@echo "Dependencias basicas do Lab 3 encontradas."

# Compila o firewall. -g preserva informacoes BTF no objeto eBPF.
build: check
	@echo "Compilando o firewall XDP..."
	@clang -O2 -g -target bpf -D__TARGET_ARCH_x86 -I"$(ARCH_INCLUDE)" \
		-c xdp_fw_map.bpf.c -o xdp_fw_map.o || { \
			echo "ERRO: falha ao compilar xdp_fw_map.bpf.c."; \
			echo "Leia o diagnostico do Clang e confira clang, libbpf-dev e os headers."; exit 1; }
	@echo "Programa eBPF compilado."

# Cria um unico enlace h2--h1. h2 recebe dois enderecos de origem:
# 10.0.1.2 sera inserido na blacklist e 10.0.1.3 sera o controle.
# Como os dois entram por h1:eth1, ambos atravessam o mesmo programa XDP.
setup: build
	@set -Eeuo pipefail; \
	cleanup() { \
		sudo containerlab destroy -t topology.yml --cleanup >/dev/null 2>&1 || true; \
		sudo rm -f /var/run/netns/h1 /var/run/netns/h2; \
		rm -f "$(MAP_ID_FILE)"; \
	}; \
	on_error() { \
		status=$$?; \
		echo "ERRO: nao foi possivel preparar a topologia do Lab 3."; \
		echo "Leia a mensagem acima para identificar o comando que falhou."; \
		echo "A preparacao incompleta sera removida automaticamente."; \
		cleanup; exit $$status; \
	}; \
	trap cleanup INT TERM; \
	trap on_error ERR; \
	cleanup; \
	sudo containerlab deploy -t topology.yml; \
	H1_PID=$$(sudo docker inspect -f '{{.State.Pid}}' "$(H1_CONTAINER)"); \
	H2_PID=$$(sudo docker inspect -f '{{.State.Pid}}' "$(H2_CONTAINER)"); \
	sudo mkdir -p /var/run/netns; \
	sudo ln -sf "/proc/$$H1_PID/ns/net" /var/run/netns/h1; \
	sudo ln -sf "/proc/$$H2_PID/ns/net" /var/run/netns/h2; \
	sudo ip netns exec h1 ip addr replace 10.0.1.1/24 dev eth1; \
	sudo ip netns exec h2 ip addr replace 10.0.1.2/24 dev eth1; \
	sudo ip netns exec h2 ip addr add 10.0.1.3/24 dev eth1; \
	sudo ip netns exec h1 ip link set eth1 up; \
	sudo ip netns exec h2 ip link set eth1 up; \
	trap - ERR INT TERM; \
	echo "Ambiente do Lab 3 preparado."; \
	echo "Comece com: make test-baseline"

# Confirma que setup foi executado antes de qualquer experimento.
verify-env:
	@test -f xdp_fw_map.o || { \
		echo "ERRO: o programa eBPF ainda nao foi compilado."; \
		echo "Execute primeiro: make setup"; exit 1; }
	@sudo ip netns exec h1 true >/dev/null 2>&1 && \
	 sudo ip netns exec h2 true >/dev/null 2>&1 || { \
		echo "ERRO: os namespaces h1 e h2 nao estao acessiveis."; \
		echo "A topologia pode ter sido encerrada. Execute: make setup"; exit 1; }

# Linha de base: os dois enderecos atravessam o mesmo enlace sem XDP.
test-baseline: verify-env
	@set -euo pipefail; \
	sudo ip netns exec h1 ip link set dev eth1 xdpgeneric off >/dev/null 2>&1 || true; \
	rm -f "$(MAP_ID_FILE)"; \
	echo "SAIDA TECNICA - ENDERECO QUE SERA BLOQUEADO (10.0.1.2)"; \
	echo "------------------------------------------------------------"; \
	sudo ip netns exec h2 ping -I 10.0.1.2 -c 2 -W 2 10.0.1.1 || { \
		echo "ERRO: 10.0.1.2 nao alcancou h1 sem XDP."; \
		echo "Execute make setup novamente e confira as mensagens da topologia."; exit 1; }; \
	echo; \
	echo "SAIDA TECNICA - ENDERECO DE CONTROLE (10.0.1.3)"; \
	echo "------------------------------------------------------------"; \
	sudo ip netns exec h2 ping -I 10.0.1.3 -c 2 -W 2 10.0.1.1 || { \
		echo "ERRO: 10.0.1.3 nao alcancou h1 sem XDP."; exit 1; }; \
	echo; \
	echo "============================================================"; \
	echo " LINHA DE BASE - Os dois enderecos passam sem o firewall"; \
	echo "============================================================"; \
	echo; \
	echo "OBJETIVO"; \
	echo "  Confirmar que 10.0.1.2 e 10.0.1.3 alcancam h1 antes"; \
	echo "  de ativar o programa XDP."; \
	echo; \
	echo "O QUE ACONTECEU"; \
	echo "  [OK] Os dois enderecos usaram h2:eth1 -> h1:eth1."; \
	echo "  [OK] Os dois receberam respostas."; \
	echo; \
	echo "CONCLUSAO"; \
	echo "  [SUCESSO] A rede funciona normalmente sem o firewall."; \
	echo

# Anexa o XDP generico e registra o ID exato do map criado.
test-empty-map: verify-env
	@set -euo pipefail; \
	sudo ip netns exec h1 ip link set dev eth1 xdpgeneric off >/dev/null 2>&1 || true; \
	rm -f "$(MAP_ID_FILE)"; \
	echo "Anexando XDP generico ao ingresso de h1:eth1..."; \
	if ! sudo ip netns exec h1 ip link set dev eth1 xdpgeneric obj "$(CURDIR)/xdp_fw_map.o" sec xdp; then \
		echo "ERRO: o kernel nao aceitou o programa XDP generico em h1:eth1."; \
		echo "Confira os recursos eBPF com: sudo bpftool feature probe kernel"; \
		echo "Depois execute: make clean && make setup"; exit 1; \
	fi; \
	MAP_ID=$$(sudo bpftool map show | awk '/name blacklist / {gsub(":", "", $$1); id=$$1} END {print id}'); \
	test -n "$$MAP_ID" || { \
		echo "ERRO: XDP foi anexado, mas o map blacklist nao foi localizado."; \
		echo "Inspecione com: sudo bpftool map list"; exit 1; }; \
	echo "$$MAP_ID" > "$(MAP_ID_FILE)"; \
	echo "SAIDA TECNICA - INTERFACE COM XDP"; \
	echo "------------------------------------------------------------"; \
	sudo ip netns exec h1 ip -details link show dev eth1; \
	echo; \
	echo "SAIDA TECNICA - BLACKLIST VAZIA"; \
	echo "------------------------------------------------------------"; \
	sudo bpftool map dump id "$$MAP_ID"; \
	echo; \
	echo "SAIDA TECNICA - PING COM MAP VAZIO"; \
	echo "------------------------------------------------------------"; \
	sudo ip netns exec h2 ping -I 10.0.1.2 -c 2 -W 2 10.0.1.1 || { \
		echo "ERRO: o ping falhou mesmo com a blacklist vazia."; \
		echo "Execute make test-baseline para separar uma falha de rede de uma falha do XDP."; exit 1; }; \
	echo; \
	echo "============================================================"; \
	echo " MAP VAZIO - XDP consulta a blacklist e permite o trafego"; \
	echo "============================================================"; \
	echo; \
	echo "O QUE ACONTECEU"; \
	echo "1. XDP foi anexado ao ingresso de h1:eth1."; \
	echo "2. A blacklist nao continha nenhuma chave."; \
	echo "3. 10.0.1.2 nao foi encontrado e seus pacotes passaram."; \
	echo; \
	echo "CONCLUSAO"; \
	echo "  [SUCESSO] Um map vazio nao bloqueia o trafego."; \
	echo

# Atualiza o map pelo userspace e compara duas origens no mesmo hook XDP.
test-block: verify-env
	@set -euo pipefail; \
	test -s "$(MAP_ID_FILE)" || { \
		echo "ERRO: o map deste laboratorio ainda nao foi preparado."; \
		echo "Execute primeiro: make test-empty-map"; exit 1; }; \
	MAP_ID=$$(cat "$(MAP_ID_FILE)"); \
	sudo bpftool map show id "$$MAP_ID" >/dev/null 2>&1 || { \
		echo "ERRO: o map registrado nao existe mais; o XDP pode ter sido desanexado."; \
		echo "Execute novamente: make test-empty-map"; exit 1; }; \
	sudo bpftool map update id "$$MAP_ID" key hex 0a 00 01 02 value hex 01 00 00 00; \
	echo "SAIDA TECNICA - BLACKLIST APOS A INSERCAO"; \
	echo "------------------------------------------------------------"; \
	sudo bpftool map dump id "$$MAP_ID"; \
	echo; \
	echo "SAIDA TECNICA - 10.0.1.2 DEVE SER BLOQUEADO"; \
	echo "------------------------------------------------------------"; \
	if sudo ip netns exec h2 ping -I 10.0.1.2 -c 2 -W 2 10.0.1.1; then \
		echo "ERRO: 10.0.1.2 respondeu mesmo estando na blacklist."; exit 1; \
	else true; fi; \
	echo; \
	echo "SAIDA TECNICA - 10.0.1.3 DEVE CONTINUAR PERMITIDO"; \
	echo "------------------------------------------------------------"; \
	sudo ip netns exec h2 ping -I 10.0.1.3 -c 2 -W 2 10.0.1.1 || { \
		echo "ERRO: o endereco de controle tambem foi bloqueado."; exit 1; }; \
	echo; \
	echo "============================================================"; \
	echo " BLACKLIST ATIVA - Comparar a origem bloqueada e o controle"; \
	echo "============================================================"; \
	echo; \
	echo "O QUE ACONTECEU"; \
	echo "1. O userspace inseriu 10.0.1.2 no map."; \
	echo "2. XDP descartou os pacotes com essa origem."; \
	echo "3. 10.0.1.3 atravessou o mesmo XDP e continuou permitido."; \
	echo; \
	echo "CONCLUSAO"; \
	echo "  [SUCESSO] O map alterou a politica de forma seletiva,"; \
	echo "  sem recompilar nem recarregar o programa eBPF."; \
	echo

# Remove a chave e comprova que a politica muda imediatamente.
test-unblock: verify-env
	@set -euo pipefail; \
	test -s "$(MAP_ID_FILE)" || { \
		echo "ERRO: o map deste laboratorio nao foi localizado."; \
		echo "Execute primeiro: make test-empty-map e make test-block"; exit 1; }; \
	MAP_ID=$$(cat "$(MAP_ID_FILE)"); \
	sudo bpftool map delete id "$$MAP_ID" key hex 0a 00 01 02 || { \
		echo "ERRO: 10.0.1.2 nao estava na blacklist."; \
		echo "Execute primeiro: make test-block"; exit 1; }; \
	echo "SAIDA TECNICA - BLACKLIST APOS A REMOCAO"; \
	echo "------------------------------------------------------------"; \
	sudo bpftool map dump id "$$MAP_ID"; \
	echo; \
	echo "SAIDA TECNICA - 10.0.1.2 LIBERADO"; \
	echo "------------------------------------------------------------"; \
	sudo ip netns exec h2 ping -I 10.0.1.2 -c 2 -W 2 10.0.1.1 || { \
		echo "ERRO: 10.0.1.2 continuou sem resposta depois de ser removido do Map."; \
		echo "Confira o conteudo exibido acima e repita desde: make test-empty-map"; exit 1; }; \
	echo; \
	echo "============================================================"; \
	echo " REMOCAO - Liberar o endereco sem recarregar o programa"; \
	echo "============================================================"; \
	echo; \
	echo "O QUE ACONTECEU"; \
	echo "1. O userspace removeu 10.0.1.2 do map."; \
	echo "2. XDP deixou de encontrar o endereco na blacklist."; \
	echo "3. O ping voltou a receber respostas imediatamente."; \
	echo; \
	echo "CONCLUSAO"; \
	echo "  [SUCESSO] A conectividade foi restaurada sem recompilar XDP."; \
	echo "  Para encerrar o experimento, execute: make detach-xdp"; \
	echo

# Desanexa especificamente o modo generico usado pelo laboratorio.
detach-xdp: verify-env
	@sudo ip netns exec h1 ip link set dev eth1 xdpgeneric off >/dev/null 2>&1 || true
	@rm -f "$(MAP_ID_FILE)"
	@echo "Programa XDP desanexado de h1:eth1. A topologia continua ativa."

destroy:
	@sudo containerlab destroy -t topology.yml --cleanup || true
	@sudo rm -f /var/run/netns/h1 /var/run/netns/h2
	@rm -f "$(MAP_ID_FILE)"

clean: destroy
	@rm -f xdp_fw_map.o
	@echo "Topologia e objetos do Lab 3 removidos."
