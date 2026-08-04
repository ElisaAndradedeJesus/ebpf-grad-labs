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
2. [Por que estender o kernel é difícil?](#por-que-estender-o-kernel-é-difícil)
3. [O ciclo de vida de um programa eBPF](#o-ciclo-de-vida-de-um-programa-ebpf)
4. [O Verifier, o contexto e os helpers](#o-verifier-o-contexto-e-os-helpers)
5. [O contrato com o Kernel](#o-contrato-com-o-kernel-tipos-de-programas)
6. [Comunicação com o userspace por meio de Maps](#comunicação-com-o-userspace-por-meio-de-maps)
7. [Portabilidade, BTF e CO-RE](#portabilidade-btf-e-co-re)
8. [Preparando o ambiente de desenvolvimento](#preparando-ambiente-de-desenvolvimento)
   1. [Requisitos](#requisitos)
   2. [Instalando WSL e Ubuntu](#instalando-wsl-e-ubuntu)
   3. [Atualizar o Ubuntu](#atualizar-o-ubuntu)
   4. [Reiniciar o WSL após a atualização](#reiniciar-o-wsl-após-a-atualização)
   5. [Abrir o Ubuntu](#abrir-o-ubuntu)
   6. [Instalar dependências comuns](#instalar-dependências-comuns)
   7. [Instalar o Docker](#instalar-o-docker)
   8. [Instalar o Containerlab](#instalar-o-containerlab)
   9. [Clonar o repositório](#clonar-o-repositório)
9. [Laboratórios disponíveis](#laboratórios-disponíveis)
10. [Por que WSL2](#por-que-wsl2)
11. [Cuidados específicos no WSL2](#cuidados-específicos-no-wsl2)
12. [Soluções de problemas](#soluções-de-problemas)
13. [Referências](#referências)

## 🧠 O que é o eBPF? (Introdução Teórica)

Historicamente, o sistema operacional é dividido em dois espaços por motivos de segurança e estabilidade:
1. **User Space (Espaço do Usuário):** Onde rodam suas aplicações normais (navegadores, bancos de dados, scripts Python).
2. **Kernel Space (Espaço do Núcleo):** O coração do sistema operacional, que tem acesso irrestrito ao hardware (CPU, memória, placas de rede).

Se você quisesse adicionar uma funcionalidade profunda ao Kernel (como um novo algoritmo de rede ou uma ferramenta de telemetria), precisava escrever um **Módulo de Kernel (LKM)**. O problema é que um único erro de ponteiro em um Módulo de Kernel causa um *Kernel Panic*, travando e reiniciando a máquina inteira.

**O eBPF oferece uma alternativa para muitos desses casos.** Ele é frequentemente comparado ao "JavaScript do Kernel". A comparação ajuda a transmitir a ideia de código carregado dinamicamente em um ambiente controlado, mas não deve ser interpretada literalmente: programas eBPF possuem tipos, pontos de anexação e recursos rigorosamente limitados pelo Kernel.

Uma camada essencial de segurança do eBPF é o **Verificador (Verifier)**: um componente interno do Linux que analisa o programa antes de permitir seu carregamento. Se o código não provar que termina, tentar acessar memória proibida ou violar as regras do seu tipo, o Verifier o rejeita.

O nome significa *Extended Berkeley Packet Filter* e revela a origem da tecnologia em filtragem de pacotes. Entretanto, o eBPF moderno não se limita à rede. Ele também é utilizado em observabilidade, análise de desempenho e aplicação de políticas de segurança.

## Por que estender o Kernel é difícil?

Aplicações recorrem constantemente ao Kernel para abrir arquivos, criar processos, utilizar memória e enviar dados pela rede. Observar ou modificar esses pontos permite construir ferramentas muito poderosas, mas alterar o Kernel tradicionalmente exige:

- modificar seu código-fonte e aguardar a distribuição de uma nova versão; ou
- carregar um módulo que passa a executar com privilégios de Kernel.

Nos dois casos, um erro pode comprometer a estabilidade de toda a máquina. Além disso, uma mudança incorporada ao Kernel precisa atender muitos usuários e ambientes diferentes.

O eBPF permite carregar uma funcionalidade específica dinamicamente, sem recompilar o Kernel e sem obrigar outros sistemas a adotar a mesma mudança. Essa flexibilidade não elimina os riscos: carregar programas eBPF exige privilégios e só deve ser feito com código confiável.

## O ciclo de vida de um programa eBPF

Um programa eBPF não começa a funcionar apenas porque seu código C existe. Ele passa por uma sequência:

```text
código-fonte C
      ↓ clang/LLVM
objeto ELF com bytecode eBPF
      ↓ ferramenta no userspace, como bpftool
Verifier analisa o programa
      ↓ programa aceito
programa é carregado no Kernel
      ↓ anexação a um hook
um evento aciona o programa
      ↓
o programa observa, permite, descarta ou bloqueia uma operação
```

O arquivo `.bpf.o` gerado pelo Clang é um objeto ELF. Ele contém o bytecode que será apresentado ao Kernel e também pode conter definições de Maps. Uma ferramenta no userspace, como `bpftool`, solicita o carregamento e a anexação.

Carregar e anexar são ações diferentes:

- **carregar** coloca o programa verificado no Kernel;
- **anexar** conecta o programa a um evento ou ponto específico;
- **desanexar** remove essa conexão;
- **descarregar** acontece quando não resta nenhuma referência ao programa.

Essa distinção aparece nos Makefiles dos laboratórios, que separam preparação, anexação, testes e limpeza.

## O Verifier, o contexto e os helpers

Antes do carregamento, o Verifier analisa os caminhos possíveis do programa. Entre outras verificações, ele exige que:

- a execução termine em um número limitado de instruções;
- ponteiros sejam validados antes de serem acessados;
- leituras e escritas permaneçam dentro das regiões permitidas;
- o programa utilize somente recursos compatíveis com seu tipo.

Cada hook fornece um **contexto**, isto é, os dados de entrada disponíveis naquele ponto. Um programa XDP recebe informações sobre um pacote de rede; um Kprobe recebe o contexto relacionado à função observada. O programa não pode presumir que qualquer dado do Kernel está disponível.

Os **helpers** são funções oferecidas pelo Kernel aos programas eBPF. A lista permitida depende do tipo do programa. Essa é uma parte importante do contrato: um helper adequado ao processamento de pacotes pode não estar disponível para um programa de tracing.

Ser aceito pelo Verifier significa que o programa respeita as regras de segurança verificáveis, não que sua lógica está correta. Um programa pode ser seguro para o Kernel e ainda tomar uma decisão equivocada. Por isso os laboratórios comparam uma linha de base com o comportamento após a anexação.

## 🏗️ O Contrato com o Kernel: Tipos de Programas

Os tipos de programas eBPF (*program types*) definem o "contrato" entre o seu código e o Kernel do Linux. Cada tipo determina onde o programa pode ser anexado, quais *helpers* (funções auxiliares) ele pode chamar e qual é o formato do contexto (os dados de entrada) que ele recebe.

Eles são divididos nas seguintes categorias principais:

1. **Networking (Rede):** A categoria mais popular, onde o eBPF brilha ao processar pacotes em alta velocidade. Inclui o **XDP** (executado no driver da placa de rede) e o **TC** (Traffic Control, anexado à camada de roteamento do kernel).
2. **Tracing e Monitoramento:** Permitem observar o comportamento interno do sistema operacional e de aplicações em tempo real, sem reinicialização. Inclui o **Kprobe**, que permite anexar código eBPF a quase qualquer função interna do Kernel.
3. **Segurança e Controle de Acesso:** Focados em garantir que o sistema opere dentro de políticas permitidas. Inclui o **LSM (Linux Security Modules)**, que permite criar políticas para vetar operações diretamente nos ganchos de segurança do sistema.

O Kernel impõe restrições rígidas por segurança. Um programa de tracing acessa somente o contexto e os helpers permitidos para seu tipo e não pode assumir as capacidades de um programa de rede. Da mesma forma, um programa XDP recebe o contexto do pacote e não o contexto de uma operação de abertura de arquivo.

Nos laboratórios, esses contratos aparecem de maneira concreta:

| Programa | Ponto de anexação | Evento observado | Possível resultado |
|---|---|---|---|
| Kprobe | entrada de `__x64_sys_execve` | tentativa de executar um programa | registrar o evento |
| BPF LSM | `bprm_check_security` | verificação de segurança antes da execução | permitir ou negar |
| XDP | ingresso de uma interface | recebimento de um pacote | passar ou descartar |
| TC | caminho de saída de uma interface | envio de um pacote | permitir ou descartar |

No Lab 1, portanto, o Kprobe não observa uma porta de rede. Ele é acionado quando o Kernel entra na função `__x64_sys_execve`. O BPF LSM é o componente que tenta impedir a execução do `curl`, quando esse recurso está ativo no Kernel utilizado.

## Comunicação com o userspace por meio de Maps

Programas eBPF executam no Kernel, mas frequentemente precisam receber configurações ou entregar informações a aplicações no userspace. Os **eBPF Maps** realizam essa comunicação.

Maps são estruturas de dados mantidas pelo Kernel. Existem diferentes tipos, mas muitos podem ser compreendidos como armazenamento de pares chave–valor. Eles permitem, por exemplo:

- o programa eBPF registrar métricas para o userspace consultar;
- o userspace fornecer configurações que alteram o comportamento do programa;
- diferentes programas eBPF compartilharem informações.



## Portabilidade, BTF e CO-RE

Estruturas internas do Kernel podem mudar entre versões. Um programa compilado supondo um formato específico pode encontrar outro formato na máquina de destino.

O **BTF (BPF Type Format)** descreve tipos e estruturas do Kernel. A abordagem **CO-RE (*Compile Once – Run Everywhere*)** utiliza essas informações, com suporte do Clang e da libbpf, para reduzir problemas de portabilidade.

O arquivo `/sys/kernel/btf/vmlinux` expõe o BTF do Kernel em execução. No Lab 1, o `bpftool` transforma essas informações em `vmlinux.h`, usado durante a compilação do programa BPF LSM:

```text
/sys/kernel/btf/vmlinux
          ↓ bpftool
      vmlinux.h
          ↓ clang
   programa eBPF compilado
```

CO-RE facilita a portabilidade, mas não garante que todo hook ou recurso exista em qualquer Kernel. O BPF LSM, por exemplo, precisa estar habilitado e ativo. Essa é a razão de o Lab 1 verificar o ambiente e continuar apenas com o Kprobe quando o BPF LSM não está disponível no WSL 2.

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

### Instalar o Docker

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

Cada pasta possui um README próprio com preparação, testes e resultados esperados.

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

- Liz Rice. *What Is eBPF? An Introduction to a New Generation of Networking, Security, and Observability Tools*. O’Reilly Media, 2022.
- Repositório da disciplina: https://github.com/nerds-ufes/Prog-Networks-2026
- Microsoft WSL: https://learn.microsoft.com/windows/wsl/install
- Docker Engine no Ubuntu: https://docs.docker.com/engine/install/ubuntu/
- Containerlab: https://containerlab.dev/install/
- eBPF: https://ebpf.io/
- libbpf: https://github.com/libbpf/libbpf
- BCC: https://github.com/iovisor/bcc
