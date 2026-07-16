#!/bin/bash
set -e

echo "=== LAB 2: XDP e TC ==="
echo "[1/4] Compilando eBPF..."
clang -O2 -target bpf -c xdp_drop_icmp.bpf.c -o xdp.o
clang -O2 -target bpf -c tc_egress_drop.bpf.c -o tc.o

echo "[2/4] Subindo Topologia..."
sudo containerlab deploy -t topology.yml

H1_PID=$(docker inspect -f '{{.State.Pid}}' clab-ebpf-lab2-h1)
H2_PID=$(docker inspect -f '{{.State.Pid}}' clab-ebpf-lab2-h2)
sudo mkdir -p /var/run/netns
sudo ln -sf /proc/$H1_PID/ns/net /var/run/netns/h1
sudo ln -sf /proc/$H2_PID/ns/net /var/run/netns/h2

echo "[3/4] XDP em H1 (Bloqueando Entrada Ping)..."
sudo ip netns exec h1 ip link set dev eth1 xdp obj xdp.o sec xdp
if sudo ip netns exec h2 ping -c 1 -W 1 172.20.20.2 > /dev/null 2>&1; then
    echo "❌ FALHA: Ping passou!"
else
    echo "✅ SUCESSO: Ping bloqueado pelo XDP!"
fi

echo -e "\n[4/4] TC em H2 (Bloqueando Saída HTTP)..."
sudo ip netns exec h2 tc qdisc add dev eth1 clsact
sudo ip netns exec h2 tc filter add dev eth1 egress bpf obj tc.o sec classifier
if sudo ip netns exec h2 nc -z -w 1 172.20.20.2 80 2>/dev/null; then
    echo "❌ FALHA: Conexão HTTP permitida!"
else
    echo "✅ SUCESSO: Pacote destruído na saída pelo TC Egress!"
fi

echo "Limpando..."
sudo containerlab destroy -t topology.yml
sudo rm -f /var/run/netns/h1 /var/run/netns/h2 *.o