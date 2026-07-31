# 🚀 Laboratórios Práticos de eBPF: Programação Nativa no Kernel Linux

Bem-vindos à disciplina prática de **eBPF (Extended Berkeley Packet Filter)**. Este repositório contém laboratórios progressivos sobre observabilidade, segurança e processamento de pacotes no Kernel Linux. Os experimentos de rede utilizam ambientes isolados com o **Containerlab**.

> **Ambiente-alvo:** estes laboratórios foram projetados e devem ser validados no Windows 11 com **WSL 2**, Ubuntu, Docker Engine e Containerlab. A execução em outras distribuições ou diretamente sobre Linux pode exigir adaptações nos hooks, caminhos e recursos oferecidos pelo kernel.

<!-- ## Atualizando repositório local

Seção temporária para facilitar a atualização dos repositórios locais nas máquinas de teste.

```bash
cd ~
rm -rf ~/ebpf-grad-labs
test ! -e ~/ebpf-grad-labs && echo "Repositório removido"
git clone https://github.com/ElisaAndradedeJesus/ebpf-grad-labs.git
cd ebpf-grad-labs
``` -->

---

## Sumário

1. [O que é o eBPF?](#o-que-é-o-ebpf-introdução-teórica)
2. [O Contrato com o Kernel](#o-contrato-com-o-kernel-tipos-de-programas)
3. [Preparando o ambiente de desenvolvimento](#preparando-ambiente-de-desenvolvimento)
   1. [Requisitos](#requisitos)
   2. [Instalando WSL e Ubuntu](#instalando-wsl-e-ubuntu)
   3. [Abrir o Ubuntu](#abrir-o-ubuntu)
   4. [Atualizar o Ubuntu](#atualizar-o-ubuntu)
   5. [Reiniciar o WSL após a atualização](#reiniciar-o-wsl-após-a-atualização)
   6. [Instalar dependências comuns](#instalar-dependências-comuns)
   7. [Instalar e testar o Docker](#instalar-e-testar-o-docker)
   8. [Instalar e testar o Containerlab](#instalar-e-testar-o-containerlab)
   9. [Clonar o repositório](#clonar-o-repositório)
4. [Laboratórios disponíveis](#laboratórios-disponíveis)
5. [Por que WSL2](#por-que-wsl2)
6. [Cuidados específicos no WSL2](#cuidados-específicos-no-wsl2)
7. [Soluções de problemas](#soluções-de-problemas)
8. [Referências](#referências)

## 🧠 O que é o eBPF? (Introdução Teórica)

Historicamente, o sistema operacional é dividido em dois espaços por motivos de segurança e estabilidade:
1. **User Space (Espaço do Usuário):** Onde rodam suas aplicações normais (navegadores, bancos de dados, scripts Python).
2. **Kernel Space (Espaço do Núcleo):** O coração do sistema operacional, que tem acesso irrestrito ao hardware (CPU, memória, placas de rede).

Se você quisesse adicionar uma funcionalidade profunda ao Kernel (como um novo algoritmo de rede ou uma ferramenta de telemetria), precisava escrever um **Módulo de Kernel (LKM)**. O problema é que um único erro de ponteiro em um Módulo de Kernel causa um *Kernel Panic*, travando e reiniciando a máquina inteira.

**O eBPF resolve esse problema.** Ele é frequentemente comparado ao "JavaScript do Kernel". Assim como o JavaScript permite que os navegadores executem códigos dinâmicos de forma segura dentro de uma *sandbox*, o eBPF permite executar mini-programas dinâmicos diretamente no Kernel Linux, sem precisar alterar o código-fonte do Sistema Operacional ou carregar módulos perigosos.

A segurança do eBPF é garantida pelo **Verificador (Verifier)**: um juiz estrito interno do Linux que analisa seu código antes de executá-lo. Se o seu código tiver loops infinitos, acessar memória proibida ou for inseguro, o Verificador o rejeita instantaneamente.

## 🏗️ O Contrato com o Kernel: Tipos de Programas

Os tipos de programas eBPF (*program types*) definem o "contrato" entre o seu código e o Kernel do Linux. Cada tipo determina onde o programa pode ser anexado, quais *helpers* (funções auxiliares) ele pode chamar e qual é o formato do contexto (os dados de entrada) que ele recebe.

Eles são divididos nas seguintes categorias principais:

1. **Networking (Rede):** A categoria mais popular, onde o eBPF brilha ao processar pacotes em alta velocidade. Inclui o **XDP** (executado no driver da placa de rede) e o **TC** (Traffic Control, anexado à camada de roteamento do kernel).
2. **Tracing e Monitoramento:** Permitem observar o comportamento interno do sistema operacional e de aplicações em tempo real, sem reinicialização. Inclui o **Kprobe**, que permite anexar código eBPF a quase qualquer função interna do Kernel.
3. **Segurança e Controle de Acesso:** Focados em garantir que o sistema opere dentro de políticas permitidas. Inclui o **LSM (Linux Security Modules)**, que permite criar políticas para vetar operações diretamente nos ganchos de segurança do sistema.

O Kernel impõe restrições rígidas por segurança. Um programa de Tracing tem acesso a quase tudo do sistema, mas não pode modificar o conteúdo de um pacote de rede. Por outro lado, um programa XDP de rede não consegue ler o nome de um arquivo sendo aberto pelo usuário.

---

## Preparando Ambiente de Desenvolvimento

### Requisitos

No Windows:

- Windows 11.
- Virtualização habilitada no firmware/BIOS.
- PowerShell.
- Acesso à internet para baixar Ubuntu, Docker, Containerlab e imagens Docker.

No Ubuntu WSL2:

- usuário com permissão de `sudo`;
- pelo menos 10 GB livres para imagens Docker e builds;
- 16 GB de RAM ou mais é recomendado para executar os laboratórios com folga.

### Instalando WSL e Ubuntu

Abra o PowerShell no Windows e execute:

```powershell
wsl --install
```

Esse comando habilita os componentes necessários do WSL e instala uma distribuição Ubuntu por padrão.

Na primeira abertura do Ubuntu, o sistema vai pedir:

1. nome de usuário Linux;
2. senha Linux;
3. confirmação da senha.

Essa senha será usada com `sudo` dentro do Ubuntu. Ela não precisa ser igual à senha do Windows.

Se precisar listar as distribuições disponíveis:

```powershell
wsl --list --online
```

Se o Ubuntu 26.04 aparecer na lista, ele pode ser instalado explicitamente com o nome exibido pelo próprio comando. Exemplo:

```powershell
wsl --install -d Ubuntu-26.04
```
**Se o Windows pedir para reiniciar o computador, reinicie antes de continuar.**


### Atualizar o Ubuntu

Dentro do Ubuntu:

```bash
sudo apt update
sudo apt upgrade -y
```

O comando `apt update` atualiza a lista de pacotes disponíveis. O comando `apt upgrade -y` atualiza os pacotes já instalados.

### Reiniciar o WSL após a atualização


> Na primeira instalação, o `apt upgrade` pode atualizar componentes do próprio
> WSL e do `systemd`. Reinicie o WSL antes de instalar as dependências para que
> a nova sessão carregue todas as versões atualizadas.

Primeiro, saia do Ubuntu:

```bash
exit
```

De volta ao **PowerShell do Windows**, encerre completamente o WSL:

```powershell
wsl --shutdown
```

Depois que o comando terminar, abra uma nova sessão:

```powershell
wsl
```

O comando `wsl --shutdown` fecha todas as distribuições WSL em execução. Para
abrir novamente, você também pode usar o Ubuntu pelo menu Iniciar em vez do
comando `wsl`.

### Abrir o Ubuntu

Você pode abrir o Ubuntu pelo menu Iniciar do Windows ou digitando no PowerShell:

```powershell
wsl
```

Não execute comandos dentro de pastas do sistema do Windows, como:

```text
/mnt/c/WINDOWS/system32
```

Executar comandos a partir desse diretório pode causar erro de permissão porque o Windows protege pastas do sistema.

Antes de executar qualquer comando, volte para sua home Linux:

```bash
cd ~
```

### Instalar dependências comuns

Os READMEs dos laboratórios explicam a execução de cada experimento, mas alguns pacotes são usados antes ou ao redor deles.

Instale o conjunto comum abaixo no Ubuntu WSL2:

```bash
sudo apt install -y \
  git curl wget ca-certificates gnupg lsb-release software-properties-common \
  build-essential make cmake pkg-config gcc gcc-multilib \
  clang llvm clang-18 llvm-18 \
  libbpf-dev libelf-dev zlib1g-dev libpcap-dev libssl-dev libcap-dev libnuma-dev \
  bpftool bpfcc-tools python3-bpfcc libbpfcc-dev \
  python3 python3-pip python3-dev python3-venv \
  iproute2 net-tools iputils-ping tcpdump iperf3 hping3 ethtool \
  linux-headers-generic linux-tools-common linux-tools-generic \
  dwarves pahole trace-cmd tmux vim nano file
```

Durante a instalação, o pacote complementar `iperf3` pode abrir uma tela perguntando:

```text
Start Iperf3 as a daemon automatically?
```

Escolha `<No>`. Use `Tab` para alternar entre as opções e `Enter` para confirmar. Os três laboratórios atuais não utilizam o `iperf3`, então ele não precisa ficar rodando automaticamente no Ubuntu/WSL2.

O Lab 1 depende do BTF do kernel. Esse requisito aparece em [Cuidados específicos no WSL2](#cuidados-específicos-no-wsl2) e nas soluções de problemas.

### Instalar e testar o Docker

Antes de instalar o Docker, garanta que o `apt update` não está falhando:

```bash
sudo apt update
```

Instale o Docker Engine:

```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
```

O instalador pode avisar que detectou WSL e recomendar Docker Desktop. Para este ambiente, continue com o Docker Engine dentro do Ubuntu WSL2.

### Instalar o Containerlab

Instale o Containerlab:

```bash
bash -c "$(curl -sL https://get.containerlab.dev)"
```

### Clonar o repositório


Clone o repositório:

```bash
git clone https://github.com/ElisaAndradedeJesus/ebpf-grad-labs.git
cd ebpf-grad-labs

```

Confirme onde você está:

```bash
pwd
ls
```

O caminho deve estar dentro de `/home/seu_usuario/ebpf-grad-labs`, não em `/mnt/c/...`.

## Laboratórios disponíveis

Cada pasta possui um README próprio com preparação, testes, resultados esperados e limpeza.

1. [Lab 1 — Kprobe e BPF LSM](Lab1-Tipos_eBPF/README.md): compara observabilidade com Kprobe e bloqueio com BPF LSM.
2. [Lab 2 — XDP ingress e TC egress](Lab2-XDP_vs_TC/README.md): compara o descarte de tráfego no ingresso e na saída.
3. [Lab 3 — Firewall dinâmico com eBPF Maps](Lab3-Mapas_eBPF_Firewall/README.md): altera uma blacklist pelo userspace sem recompilar o programa.

## Por que WSL2

WSL2 permite executar Linux no Windows 11 com um kernel Linux real, sem depender de uma máquina virtual tradicional. Para esta disciplina, isso é útil porque os laboratórios usam Docker, Containerlab, eBPF, XDP, `bpftool`, `clang`, `libbpf` e ferramentas de rede Linux.

Vantagens:

- usa ambiente Linux sem trocar o sistema operacional principal;
- permite executar Docker e Containerlab dentro do Ubuntu;
- oferece suporte a recursos Linux necessários para os laboratórios.

Limitações:

- o kernel do WSL2 não é um kernel Ubuntu genérico;
- alguns pacotes `linux-tools-$(uname -r)` podem não existir para kernels Microsoft do WSL2;
- recursos eBPF dependem do suporte oferecido pelo kernel e de permissão de administrador dentro do Linux;

## Cuidados específicos no WSL2

### Trabalhe dentro de `/home`

Dê preferência a executar builds e laboratórios dentro do repositório do projeto:

```bash
cd ~/ebpf-grad-labs
```

Além de permissões diferentes, o desempenho de I/O costuma ser pior e alguns scripts podem falhar ao montar volumes ou criar arquivos.

### Use `sudo` nos comandos de Docker e Containerlab

Os laboratórios assumem comandos com privilégios. Prefira:

```bash
sudo docker ps
sudo containerlab version
```

### Inicie o Docker ao abrir uma nova sessão WSL

Se o Docker não estiver ativo:

```bash
sudo service docker start
```

Depois confira:

```bash
sudo docker ps
```

### Cuidado com `linux-tools-$(uname -r)`

No WSL2, `uname -r` pode retornar um kernel Microsoft. Nesses casos, pacotes como `linux-tools-$(uname -r)` ou `linux-cloud-tools-$(uname -r)` podem não existir nos repositórios Ubuntu.

Quando isso acontecer, use primeiro:

```bash
sudo apt install -y bpftool linux-tools-common linux-tools-generic
```

Se um script tentar instalar ferramentas exatamente para o kernel WSL e falhar, verifique se o comando era apenas auxiliar para disponibilizar `bpftool`. Em muitos casos, o `bpftool` genérico ou o `bpftool` dentro da imagem Docker do laboratório é suficiente.

### Confirme BTF antes dos labs com CO-RE

Alguns programas precisam de `/sys/kernel/btf/vmlinux` para gerar `vmlinux.h`.

```bash
ls -lh /sys/kernel/btf/vmlinux
```

Se o arquivo não existir, atualize o WSL no PowerShell:

```powershell
wsl --update
wsl --shutdown
```

Abra o Ubuntu novamente e repita a verificação.

## Soluções de problemas

### `Permission denied` ao clonar ou executar comandos

Verifique onde você está:

```bash
pwd
```

Se estiver em `/mnt/c/WINDOWS/system32` ou outra pasta protegida do Windows, volte para a home Linux:

```bash
cd ~
```

Clone e execute o repositório dentro de `/home/seu_usuario`.

### Docker daemon não está rodando

```bash
sudo service docker start
sudo docker info
```

### Docker sem permissão

Use `sudo`, que é o padrão deste guia:

```bash
sudo docker ps
sudo docker run --rm hello-world
```

### Containerlab não encontrado

```bash
containerlab version
which containerlab
```

Se não existir, reinstale:

```bash
bash -c "$(curl -sL https://get.containerlab.dev)"
```

### `bpftool` não encontrado

```bash
which bpftool
sudo apt install -y bpftool linux-tools-common linux-tools-generic
```

Em kernels WSL2, evite depender exclusivamente de `linux-tools-$(uname -r)`, porque esse pacote pode não existir.

### `/sys/kernel/btf/vmlinux` não existe

```bash
ls -lh /sys/kernel/btf/vmlinux
uname -r
```

Atualize o WSL no PowerShell:

```powershell
wsl --update
wsl --shutdown
```

Depois abra o Ubuntu novamente.

### Limpar um laboratório que permaneceu ativo

Entre na pasta do laboratório atual e utilize o alvo de limpeza correspondente:

```bash
cd ~/ebpf-grad-labs/Lab1-Tipos_eBPF
make clean

cd ~/ebpf-grad-labs/Lab2-XDP_vs_TC
make clean

cd ~/ebpf-grad-labs/Lab3-Mapas_eBPF_Firewall
make clean
```

Confira containers restantes:

```bash
sudo docker ps -a
```

## Referências

- Repositório da disciplina: https://github.com/nerds-ufes/Prog-Networks-2026
- Microsoft WSL: https://learn.microsoft.com/windows/wsl/install
- Docker Engine no Ubuntu: https://docs.docker.com/engine/install/ubuntu/
- Containerlab: https://containerlab.dev/install/
- eBPF: https://ebpf.io/
- libbpf: https://github.com/libbpf/libbpf
- BCC: https://github.com/iovisor/bcc
