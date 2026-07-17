.PHONY: help check run destroy clean

help:
	@echo "Lab 3 - Firewall com eBPF Maps"
	@echo "  make check    verifica as dependencias do laboratorio"
	@echo "  make run      executa o laboratorio"
	@echo "  make destroy  destroi a topologia, caso ela permaneça ativa"
	@echo "  make clean    destroi a topologia e remove arquivos gerados"

check:
	@command -v clang >/dev/null || { echo "ERRO: clang nao encontrado"; exit 1; }
	@command -v bpftool >/dev/null || { echo "ERRO: bpftool nao encontrado"; exit 1; }
	@command -v docker >/dev/null || { echo "ERRO: docker nao encontrado"; exit 1; }
	@command -v containerlab >/dev/null || { echo "ERRO: containerlab nao encontrado"; exit 1; }
	@command -v ip >/dev/null || { echo "ERRO: iproute2 nao encontrado"; exit 1; }
	@sudo docker info >/dev/null
	@echo "Dependencias basicas do Lab 3 encontradas."

run: check
	@bash ./run_in_clab.sh

destroy:
	@sudo containerlab destroy -t topology.yml --cleanup || true
	@sudo rm -f -- /var/run/netns/h1 /var/run/netns/h2 /var/run/netns/h3

clean: destroy
	@rm -f -- xdp_fw_map.o
	@echo "Arquivos gerados pelo Lab 3 removidos."
