# 🚀 Laboratórios Práticos de eBPF: Programação Nativa no Kernel Linux

Bem-vindos à disciplina prática de **eBPF (Extended Berkeley Packet Filter)**. Este repositório contém laboratórios progressivos focados em explorar a fundo como interceptar e programar o Kernel Linux, utilizando ambientes isolados com o **Containerlab**.

---

## 🧠 O que é o eBPF? (Introdução Teórica)

Historicamente, o sistema operacional é dividido em dois espaços por motivos de segurança e estabilidade:
1. **User Space (Espaço do Usuário):** Onde rodam suas aplicações normais (navegadores, bancos de dados, scripts Python).
2. **Kernel Space (Espaço do Núcleo):** O coração do sistema operacional, que tem acesso irrestrito ao hardware (CPU, memória, placas de rede).

Se você quisesse adicionar uma funcionalidade profunda ao Kernel (como um novo algoritmo de rede ou uma ferramenta de telemetria), precisava escrever um **Módulo de Kernel (LKM)**. O problema é que um único erro de ponteiro em um Módulo de Kernel causa um *Kernel Panic*, travando e reiniciando a máquina inteira.

**O eBPF resolve esse problema.** Ele é frequentemente comparado ao "JavaScript do Kernel". Assim como o JavaScript permite que os navegadores executem códigos dinâmicos de forma segura dentro de uma *sandbox*, o eBPF permite executar mini-programas dinâmicos diretamente no Kernel Linux, sem precisar alterar o código-fonte do Sistema Operacional ou carregar módulos perigosos.

A segurança do eBPF é garantida pelo **Verificador (Verifier)**: um juiz estrito interno do Linux que analisa seu código antes de executá-lo. Se o seu código tiver loops infinitos, acessar memória proibida ou for inseguro, o Verificador o rejeita instantaneamente.

## 🏗️ O Contrato com o Kernel: Tipos de Programas

[cite_start]Os tipos de programas eBPF (*program types*) definem o "contrato" entre o seu código e o Kernel do Linux[cite: 1]. [cite_start]Cada tipo determina onde o programa pode ser anexado, quais *helpers* (funções auxiliares) ele pode chamar e qual é o formato do contexto (os dados de entrada) que ele recebe[cite: 2].

[cite_start]Eles são divididos nas seguintes categorias principais[cite: 3]:

1. [cite_start]**Networking (Rede):** A categoria mais popular, onde o eBPF brilha ao processar pacotes em alta velocidade[cite: 4, 5]. [cite_start]Inclui o **XDP** (executado no driver da placa de rede) [cite: 6] [cite_start]e o **TC** (Traffic Control, anexado à camada de roteamento do kernel)[cite: 8].
2. [cite_start]**Tracing e Monitoramento:** Permitem observar o comportamento interno do sistema operacional e de aplicações em tempo real, sem reinicialização[cite: 11, 12]. [cite_start]Inclui o **Kprobe**, que permite anexar código eBPF a quase qualquer função interna do Kernel[cite: 13].
3. [cite_start]**Segurança e Controle de Acesso:** Focados em garantir que o sistema opere dentro de políticas permitidas[cite: 19, 20]. [cite_start]Inclui o **LSM (Linux Security Modules)**, que permite criar políticas para vetar operações diretamente nos ganchos de segurança do sistema[cite: 21].

[cite_start]O Kernel impõe restrições rígidas por segurança[cite: 29]. [cite_start]Um programa de Tracing tem acesso a quase tudo do sistema, mas não pode modificar o conteúdo de um pacote de rede[cite: 30]. [cite_start]Por outro lado, um programa XDP de rede não consegue ler o nome de um arquivo sendo aberto pelo usuário[cite: 75].

---

## 🛠️ Pré-requisitos do Laboratório

Para compilar e rodar os programas eBPF, instale:
```bash
sudo apt update && sudo apt install -y clang llvm bpftool libbpf-dev linux-headers-$(uname -r) iproute2