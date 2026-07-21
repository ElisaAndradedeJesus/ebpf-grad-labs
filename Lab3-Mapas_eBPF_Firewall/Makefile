# Usa Bash porque os alvos setup e test utilizam funcoes, trap e pipefail.
SHELL := /bin/bash

# Headers especificos da arquitetura, necessarios durante a compilacao eBPF.
ARCH_INCLUDE := /usr/include/$(shell gcc -print-multiarch 2>/dev/null)

# Nomes criados pelo Containerlab a partir de topology.yml.
LAB_NAME := ebpf-lab3
H1_CONTAINER := clab-$(LAB_NAME)-h1
H2_CONTAINER := clab-$(LAB_NAME)-h2
H3_CONTAINER := clab-$(LAB_NAME)-h3

.PHONY: help check build setup verify-env test test-step1 test-step2 test-step3 test-step4 destroy clean

help:
	@echo "Lab 3 - Firewall dinamico com eBPF Maps"
	@echo "  make check    verifica as dependencias"
	@echo "  make build    compila o programa XDP"
	@echo "  make setup    compila e monta a topologia"
	@echo "  make test     executa as quatro etapas em sequencia"
	@echo "  make test-step1  confirma a conectividade inicial"
	@echo "  make test-step2  testa XDP com a blacklist vazia"
	@echo "  make test-step3  insere h2 e testa o bloqueio"
	@echo "  make test-step4  remove h2 e testa a liberacao"
	@echo "  make destroy  destroi uma topologia remanescente"
	@echo "  make clean    destroi a topologia e remove objetos"

# Verifica ferramentas do host antes de criar containers ou carregar eBPF.
check:
	@command -v clang >/dev/null || { \
		echo "ERRO: Clang nao foi encontrado; o firewall XDP nao pode ser compilado."; \
		echo "Instale com: sudo apt update && sudo apt install -y clang llvm"; \
		echo "Depois, execute novamente: make check"; exit 1; }
	@command -v gcc >/dev/null || { \
		echo "ERRO: GCC nao foi encontrado; ele e usado para localizar os headers da arquitetura."; \
		echo "Instale com: sudo apt install -y build-essential"; exit 1; }
	@command -v bpftool >/dev/null || { \
		echo "ERRO: bpftool nao foi encontrado; a blacklist nao pode ser localizada ou atualizada."; \
		echo "Instale com: sudo apt install -y bpftool"; \
		echo "Consulte tambem a preparacao do ambiente no README principal."; exit 1; }
	@command -v docker >/dev/null || { \
		echo "ERRO: Docker nao foi encontrado; o Containerlab depende dele para criar os hosts."; \
		echo "Volte ao README principal e conclua a secao 'Instalar e testar o Docker'."; \
		echo "Instalacao usada pelo curso:"; \
		echo "  curl -fsSL https://get.docker.com -o get-docker.sh"; \
		echo "  sudo sh get-docker.sh"; exit 1; }
	@command -v containerlab >/dev/null || { \
		echo "ERRO: Containerlab nao foi encontrado; a topologia h1--h2--h3 nao pode ser criada."; \
		echo "Volte ao README principal e conclua a secao 'Instalar e testar o Containerlab'."; \
		echo "Instale com: bash -c \"\$$(curl -sL https://get.containerlab.dev)\""; \
		echo "Depois, confirme com: containerlab version"; exit 1; }
	@command -v ip >/dev/null || { \
		echo "ERRO: o comando ip nao foi encontrado; os namespaces nao podem ser configurados."; \
		echo "Instale com: sudo apt install -y iproute2"; exit 1; }
	@sudo docker info >/dev/null 2>&1 || { \
		echo "ERRO: Docker esta instalado, mas o daemon nao esta em execucao ou nao respondeu."; \
		echo "Inicie com: sudo service docker start"; \
		echo "Teste com: sudo docker info"; \
		echo "Se continuar falhando, consulte o README principal."; exit 1; }
	@echo "Dependencias basicas do Lab 3 encontradas."

# Compila o firewall XDP e preserva informacoes BTF com -g.
build: check
	@echo "Compilando o firewall XDP..."
	@clang -O2 -g -target bpf -D__TARGET_ARCH_x86 -I"$(ARCH_INCLUDE)" \
		-c xdp_fw_map.bpf.c -o xdp_fw_map.o || { \
			echo "ERRO: falha ao compilar o firewall XDP com map."; \
			echo "Leia o diagnostico do Clang acima e confirme clang, libbpf-dev e os headers."; exit 1; }
	@echo "Programa eBPF compilado."

# O experimento cria tres namespaces. h1 recebe o XDP na interface ligada a h2;
# h2 representa o endereco que sera inserido na blacklist; h3 funciona como
# controle para demonstrar que outro cliente permanece alcançavel.
#
# A linha de base prova que h2 alcanca h1 com o map vazio. Depois, bpftool grava
# a chave IPv4 10.0.1.2 como bytes de rede (0a 00 01 02) e o valor inteiro 1 em
# little-endian (01 00 00 00). O teste final remove a chave sem recompilar o
# programa e confirma que a conectividade de h2 volta imediatamente.
# Prepara a topologia e os namespaces, mas nao anexa XDP nem altera o map.
setup: build
	@set -Eeuo pipefail; \
	cleanup() { \
		sudo containerlab destroy -t topology.yml --cleanup >/dev/null 2>&1 || true; \
		sudo rm -f /var/run/netns/h1 /var/run/netns/h2 /var/run/netns/h3; \
	}; \
	on_error() { \
		status=$$?; \
		echo "ERRO: nao foi possivel preparar a topologia do Lab 3."; \
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
	echo "Ambiente do Lab 3 preparado."; \
	echo "Execute os testes com: make test"

# Confirma os objetos e os namespaces utilizados por todas as etapas.
verify-env:
	@test -f xdp_fw_map.o || { \
		echo "ERRO: o programa eBPF do Lab 3 nao foi compilado."; \
		echo "Execute primeiro: make setup"; exit 1; }
	@sudo ip netns exec h1 true >/dev/null 2>&1 && \
	 sudo ip netns exec h2 true >/dev/null 2>&1 && \
	 sudo ip netns exec h3 true >/dev/null 2>&1 || { \
		echo "ERRO: os namespaces h1, h2 e h3 nao estao acessiveis."; \
		echo "A topologia pode ter sido encerrada. Execute novamente: make setup"; exit 1; }

test: verify-env
	@$(MAKE) --no-print-directory test-step1
	@$(MAKE) --no-print-directory test-step2
	@$(MAKE) --no-print-directory test-step3
	@$(MAKE) --no-print-directory test-step4
	@echo "Todos os testes do Lab 3 foram concluidos."
	@echo "A topologia continua ativa para inspecao. Ao terminar, execute: make clean"

# Etapa 1: testa as duas redes antes de carregar qualquer programa XDP.
test-step1: verify-env
	@set -euo pipefail; \
	sudo ip netns exec h1 ip link set dev eth1 xdp off >/dev/null 2>&1 || true; \
	echo "SAIDA TECNICA COMPLETA - H2 PINGANDO H1"; \
	echo "------------------------------------------------------------"; \
	if ! sudo ip netns exec h2 ping -c 2 -W 2 10.0.1.1; then \
		echo "ERRO: h2 nao alcancou h1 na linha de base; verifique enlace, IPs e iputils-ping."; exit 1; \
	fi; \
	echo; \
	echo "SAIDA TECNICA COMPLETA - H3 PINGANDO H1"; \
	echo "------------------------------------------------------------"; \
	if ! sudo ip netns exec h3 ping -c 2 -W 2 10.0.2.1; then \
		echo "ERRO: h3 nao alcancou h1 na linha de base; verifique enlace, IPs e iputils-ping."; exit 1; \
	fi; \
	echo; \
	echo "============================================================"; \
	echo " ETAPA 1/4 - Confirmar a conectividade antes do firewall"; \
	echo "============================================================"; \
	echo; \
	echo "OBJETIVO"; \
	echo "  Confirmar que h2 e h3 alcancam h1 antes de ativar XDP."; \
	echo "  Este resultado sera a linha de base do firewall."; \
	echo; \
	echo "PREPARACAO"; \
	echo "  [OK] O programa XDP esta desativado em h1."; \
	echo "  [OK] As duas redes do laboratorio estao configuradas."; \
	echo; \
	echo "ACAO"; \
	echo "  h2 e h3 enviaram 2 pings cada para as interfaces de h1."; \
	echo; \
	echo "O QUE ACONTECEU"; \
	echo "1. h2 enviou ping pela rede 10.0.1.0/24 e recebeu resposta."; \
	echo "2. h3 enviou ping pela rede 10.0.2.0/24 e recebeu resposta."; \
	echo "3. Ainda nao havia programa XDP nem blacklist ativa."; \
	echo; \
	echo "CONCLUSAO"; \
	echo "  [SUCESSO] Os dois clientes alcancam h1 sem o firewall."; \
	echo

# Etapa 2: carrega o XDP e demonstra que um map vazio nao bloqueia trafego.
test-step2: verify-env
	@set -euo pipefail; \
	sudo ip netns exec h1 ip link set dev eth1 xdp off >/dev/null 2>&1 || true; \
	echo "Anexando XDP em modo generico, compativel com a interface veth do Containerlab."; \
	if ! sudo ip netns exec h1 ip link set dev eth1 xdpgeneric obj "$(CURDIR)/xdp_fw_map.o" sec xdp; then \
		echo "ERRO: nao foi possivel anexar o firewall XDP generico a eth1 de h1."; \
		echo "O modo generico e usado porque pares veth no WSL podem rejeitar XDP nativo por causa do MTU do peer."; \
		echo "Verifique o suporte do kernel com: sudo bpftool feature probe kernel"; \
		exit 1; \
	fi; \
	MAP_ID=$$(sudo bpftool map show | awk '/name blacklist / {gsub(":", "", $$1); id=$$1} END {print id}'); \
	test -n "$$MAP_ID" || { \
		echo "ERRO: o map 'blacklist' nao foi encontrado depois de anexar o programa XDP."; \
		echo "Verifique o carregamento com: sudo bpftool prog list && sudo bpftool map list"; \
		exit 1; \
	}; \
	echo "SAIDA TECNICA COMPLETA - XDP ANEXADO"; \
	echo "------------------------------------------------------------"; \
	sudo ip netns exec h1 ip -details link show dev eth1; \
	echo; \
	echo "SAIDA TECNICA COMPLETA - CONTEUDO DA BLACKLIST"; \
	echo "------------------------------------------------------------"; \
	sudo bpftool map dump id "$$MAP_ID"; \
	echo; \
	echo "SAIDA TECNICA COMPLETA - PING DE H2"; \
	echo "------------------------------------------------------------"; \
	sudo ip netns exec h2 ping -c 2 -W 2 10.0.1.1; \
	echo; \
	echo "============================================================"; \
	echo " ETAPA 2/4 - Testar o firewall com a blacklist vazia"; \
	echo "============================================================"; \
	echo; \
	echo "OBJETIVO"; \
	echo "  Anexar XDP a h1 e mostrar que um map sem chaves"; \
	echo "  permite o trafego de h2."; \
	echo; \
	echo "PREPARACAO"; \
	echo "  [OK] XDP esta anexado ao ingresso de h1:eth1."; \
	echo "  [OK] A blacklist existe e nao possui enderecos."; \
	echo; \
	echo "ACAO"; \
	echo "  h2 enviou 2 pings enquanto XDP consultava o map vazio."; \
	echo; \
	echo "O QUE ACONTECEU"; \
	echo "1. O programa XDP consultou a blacklist para cada pacote."; \
	echo "2. O map estava vazio: o endereco de h2 nao foi encontrado."; \
	echo "3. O programa permitiu os pacotes e o ping respondeu."; \
	echo; \
	echo "CONCLUSAO"; \
	echo "  [SUCESSO] XDP com blacklist vazia nao bloqueou h2."; \
	echo

# Etapa 3: altera a politica pelo map, sem recompilar o programa.
test-step3: verify-env
	@set -euo pipefail; \
	MAP_ID=$$(sudo bpftool map show | awk '/name blacklist / {gsub(":", "", $$1); id=$$1} END {print id}'); \
	test -n "$$MAP_ID" || { echo "ERRO: blacklist ausente. Execute primeiro: make test-step2"; exit 1; }; \
	sudo bpftool map update id "$$MAP_ID" key hex 0a 00 01 02 value hex 01 00 00 00; \
	echo "SAIDA TECNICA COMPLETA - BLACKLIST APOS A INSERCAO"; \
	echo "------------------------------------------------------------"; \
	sudo bpftool map dump id "$$MAP_ID"; \
	echo; \
	echo "SAIDA TECNICA COMPLETA - H2 BLOQUEADO"; \
	echo "------------------------------------------------------------"; \
	if sudo ip netns exec h2 ping -c 2 -W 2 10.0.1.1; then \
		echo "FALHA: h2 passou mesmo estando na blacklist."; \
		exit 1; \
	else true; \
	fi; \
	echo; \
	echo "SAIDA TECNICA COMPLETA - H3 COMO CONTROLE"; \
	echo "------------------------------------------------------------"; \
	sudo ip netns exec h3 ping -c 2 -W 2 10.0.2.1; \
	echo; \
	echo "============================================================"; \
	echo " ETAPA 3/4 - Inserir h2 na blacklist e testar o bloqueio"; \
	echo "============================================================"; \
	echo; \
	echo "OBJETIVO"; \
	echo "  Adicionar 10.0.1.2 ao map e comprovar que somente h2"; \
	echo "  sera bloqueado, sem recompilar o programa XDP."; \
	echo; \
	echo "PREPARACAO"; \
	echo "  [OK] O firewall XDP permanece carregado."; \
	echo "  [OK] 10.0.1.2 foi inserido na blacklist."; \
	echo; \
	echo "ACAO"; \
	echo "  h2 e h3 tentaram alcancar h1 depois da mudanca do map."; \
	echo; \
	echo "O QUE ACONTECEU"; \
	echo "1. O userspace inseriu o endereco 10.0.1.2 no map."; \
	echo "2. XDP encontrou h2 na blacklist e descartou seus pacotes."; \
	echo "3. h3 nao estava no map e continuou permitido."; \
	echo; \
	echo "CONCLUSAO"; \
	echo "  [SUCESSO] A politica mudou pelo map sem recompilar XDP."; \
	echo

# Etapa 4: remove a chave e demonstra a mudanca imediata da politica.
test-step4: verify-env
	@set -euo pipefail; \
	MAP_ID=$$(sudo bpftool map show | awk '/name blacklist / {gsub(":", "", $$1); id=$$1} END {print id}'); \
	test -n "$$MAP_ID" || { echo "ERRO: blacklist ausente. Execute primeiro: make test-step2"; exit 1; }; \
	sudo bpftool map delete id "$$MAP_ID" key hex 0a 00 01 02; \
	echo "SAIDA TECNICA COMPLETA - BLACKLIST APOS A REMOCAO"; \
	echo "------------------------------------------------------------"; \
	sudo bpftool map dump id "$$MAP_ID"; \
	echo; \
	echo "SAIDA TECNICA COMPLETA - H2 LIBERADO"; \
	echo "------------------------------------------------------------"; \
	sudo ip netns exec h2 ping -c 2 -W 2 10.0.1.1; \
	echo; \
	echo "============================================================"; \
	echo " ETAPA 4/4 - Remover h2 da blacklist e liberar o trafego"; \
	echo "============================================================"; \
	echo; \
	echo "OBJETIVO"; \
	echo "  Remover 10.0.1.2 do map e comprovar que h2 volta a"; \
	echo "  passar imediatamente, sem recarregar o programa XDP."; \
	echo; \
	echo "PREPARACAO"; \
	echo "  [OK] O programa XDP permaneceu carregado durante a mudanca."; \
	echo "  [OK] O endereco de h2 foi removido da blacklist."; \
	echo; \
	echo "ACAO"; \
	echo "  h2 repetiu o ping depois da remocao da chave do map."; \
	echo; \
	echo "O QUE ACONTECEU"; \
	echo "1. O userspace removeu o endereco de h2 do map."; \
	echo "2. XDP deixou de encontrar h2 na blacklist."; \
	echo "3. Os pings de h2 voltaram a receber respostas."; \
	echo; \
	echo "CONCLUSAO"; \
	echo "  [SUCESSO] h2 foi liberado sem recompilar ou recarregar XDP."; \
	echo

# Recupera o ambiente se uma execucao anterior tiver sido interrompida.
destroy:
	@sudo containerlab destroy -t topology.yml --cleanup || true
	@sudo rm -f /var/run/netns/h1 /var/run/netns/h2 /var/run/netns/h3

clean: destroy
	@rm -f xdp_fw_map.o
	@echo "Topologia e objetos do Lab 3 removidos."
