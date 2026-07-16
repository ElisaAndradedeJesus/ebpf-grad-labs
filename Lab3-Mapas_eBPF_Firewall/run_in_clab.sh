#!/bin/bash
set -e

echo "=== LAB 3: Firewall via eBPF Maps ==="
echo "[1/4] Compilando eBPF..."
clang -O2 -g -target bpf -c xdp_fw_map.bpf.c -o xdp_fw_map.o

echo "[2/4] Subindo Topologia..."
sudo containerlab deploy -t topology.yml

H1_PID=$(docker inspect -f '{{.State.Pid}}' clab-ebpf-lab3-h1)
H2_PID=$(docker inspect -f '{{.State.Pid}}' clab-ebpf-lab3-h2)
H3_PID=$(docker inspect -f '{{.State.Pid}}' clab-ebpf-lab3-h3)

sudo mkdir -p /var/run/netns
sudo ln -sf /proc/$H1_PID/ns/net /var/run/netns/h1
sudo ln -sf /proc/$H2_PID/ns/net /var/run/netns/h2
sudo ln -sf /proc/$H3_PID/ns/net /var/run/netns/h3

sudo ip netns exec h1 ip addr add 10.0.1.1/24 dev eth1
sudo ip netns exec h2 ip addr add 10.0.1.2/24 dev eth1
sudo ip netns exec h1 ip addr add 10.0.2.1/24 dev eth2
sudo ip netns exec h3 ip addr add 10.0.2.2/24 dev eth1

echo "[3/4] Anexando XDP e Populando o Mapa (Banindo H2)..."
sudo ip netns exec h1 ip link set dev eth1 xdp obj xdp_fw_map.o sec xdp
sudo ip netns exec h1 ip link set dev eth2 xdp obj xdp_fw_map.o sec xdp

MAP_ID=$(sudo bpftool map | grep blacklist | awk '{print $1}' | tr -d ':')
# Formato do IP 10.0.1.2 em hex
sudo bpftool map update id $MAP_ID key hex 0a 00 01 02 value hex 01 00 00 00

echo "[4/4] Testando Conectividade..."
echo "H3 (Permitido) pingando H1:"
if sudo ip netns exec h3 ping -c 1 -W 1 10.0.2.1 > /dev/null 2>&1; then
    echo "✅ SUCESSO: Tráfego fluiu."
else
    echo "❌ ERRO."
fi

echo "H2 (Banido no Mapa) pingando H1:"
if sudo ip netns exec h2 ping -c 1 -W 1 10.0.1.1 > /dev/null 2>&1; then
    echo "❌ ERRO: Passou direto!"
else
    echo "✅ SUCESSO: Tráfego barrado instantaneamente pelo XDP via Mapa!"
fi

echo "Limpando..."
sudo containerlab destroy -t topology.yml
sudo rm -f /var/run/netns/h1 /var/run/netns/h2 /var/run/netns/h3 *.o