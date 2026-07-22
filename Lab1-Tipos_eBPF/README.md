# Lab 1: Kprobe e BPF LSM na prática

Neste laboratório, vamos comparar dois usos de eBPF relacionados ao comportamento do sistema operacional:

- **Kprobe:** observa a execução de programas sem impedir a operação;
- **BPF LSM:** aplica uma política de segurança capaz de impedir uma operação.

O Kprobe será anexado à função `__x64_sys_execve` do kernel para registrar a execução de processos. Quando BPF LSM estiver ativo no kernel, o segundo programa tentará impedir a execução de `/usr/bin/curl`.

> Este laboratório foi preparado para o ambiente x86-64 utilizado no curso, com Ubuntu sobre WSL 2. O nome da função observada pelo Kprobe pode ser diferente em outras arquiteturas ou versões do kernel.

## Antes de começar

Este passo a passo considera que:

- o ambiente descrito no README principal já foi preparado;
- `clang`, `gcc`, `bpftool` e `libbpf` estão instalados;
- `/sys/kernel/btf/vmlinux` está disponível;
- o usuário está na raiz do repositório `ebpf-grad-labs`.

Confirme sua localização:

```bash
pwd
ls
```

O resultado de `pwd` deve terminar em `/ebpf-grad-labs`, e o comando `ls` deve mostrar o diretório `Lab1-Tipos_eBPF`.

## Arquivos do laboratório

- `kprobe_exec.bpf.c`: registra a execução de processos;
- `lsm_block.bpf.c`: tenta impedir a execução do `curl`;
- `Makefile`: prepara, compila, carrega, testa e remove os programas.

O Makefile gera `vmlinux.h`, compila os programas e monta `bpffs` e `securityfs` caso ainda não estejam montados. Os arquivos gerados são removidos ao final.

## Executar o laboratório

### 1. Entre no diretório do Lab 1

Partindo da raiz do repositório:

```bash
cd Lab1-Tipos_eBPF
```

Confira os arquivos:

```bash
ls
```

### 2. Conheça os comandos disponíveis

```bash
make help
```

### 3. Verifique as dependências

Execute:

```bash
make check
```

### 4. Prepare o laboratório

O Makefile solicitará `sudo` apenas nas operações que exigem privilégios administrativos:

```bash
make setup
```

Esse comando verifica BTF, prepara os filesystems, gera `vmlinux.h` e compila os dois programas sem carregá-los no kernel.

### 5. Execute o teste

Depois que a preparação terminar, carregue e teste os programas:

```bash
make test
```

O teste deve:

1. carregar e anexar o Kprobe;
2. verificar se BPF LSM está ativo;
3. aguardar antes de remover os programas.

Quando aparecer a mensagem abaixo, a preparação terminou e o Kprobe está carregado no kernel:

```text
Pressione Enter para encerrar e remover os programas eBPF.
```

**Não pressione Enter ainda.** Esse será o **Terminal 1**, responsável por manter o laboratório ativo enquanto o teste é realizado.

### 6. Entenda o teste com três terminais

O teste utiliza três terminais Ubuntu ao mesmo tempo. Cada um possui uma responsabilidade diferente:

| Terminal | Responsabilidade | Comando principal |
|---|---|---|
| Terminal 1 | Carregar e manter o Kprobe ativo | `make test` |
| Terminal 2 | Exibir os eventos produzidos pelo Kprobe | `sudo cat /sys/kernel/tracing/trace_pipe` |
| Terminal 3 | Executar programas para gerar eventos | `ls`, `date` e `whoami` |

O fluxo do experimento é:

```text
Terminal 3 executa um programa
              ↓
O kernel executa __x64_sys_execve
              ↓
O Kprobe carregado pelo Terminal 1 é acionado
              ↓
O programa eBPF escreve uma mensagem de tracing
              ↓
O Terminal 2 exibe a mensagem pelo trace_pipe
```

### 7. Terminal 2: observe os eventos do Kprobe

Abra um segundo terminal Ubuntu e execute:

```bash
sudo cat /sys/kernel/tracing/trace_pipe
```

Se esse caminho não existir, tente:

```bash
sudo cat /sys/kernel/debug/tracing/trace_pipe
```

Deixe esse comando em execução. O terminal ficará aparentemente parado enquanto aguarda novas mensagens do kernel. Isso é o comportamento esperado.

### 8. Terminal 3: gere eventos de execução

Abra um terceiro terminal Ubuntu e execute, um de cada vez:

```bash
ls
date
whoami
```

Esses comandos iniciam novos programas. Cada inicialização passa pela função `__x64_sys_execve`, na qual o Kprobe está anexado.

Volte ao Terminal 2. Devem aparecer mensagens semelhantes a:

```text
KPROBE: Processo 'ls' executado!
KPROBE: Processo 'date' executado!
KPROBE: Processo 'whoami' executado!
```

O nome e a ordem dos processos podem variar porque o sistema continua executando outros programas enquanto o Kprobe está ativo.

### 9. Confirme o programa com bpftool

Ainda no Terminal 3, confirme que o programa está carregado no kernel:

```bash
sudo bpftool prog list | grep -A 4 trace_exec
```

A saída deve identificar `trace_exec` como um programa do tipo `kprobe`.

O teste do Kprobe é considerado bem-sucedido quando existem as duas evidências:

1. `bpftool` mostra o programa `trace_exec` carregado;
2. o Terminal 2 mostra mensagens geradas quando os comandos do Terminal 3 são executados.

### 10. Interprete o teste do BPF LSM

O Makefile consulta `/sys/kernel/security/lsm` antes de carregar o programa de segurança.

Se BPF LSM estiver ativo, o Makefile carregará o programa e testará `curl --version`. O resultado esperado é:

```text
SUCESSO: a execução do curl foi bloqueada pelo BPF LSM.
```

Se BPF LSM não estiver ativo, o laboratório mostrará um aviso e continuará apenas com o Kprobe:

```text
AVISO: BPF LSM não está ativo neste kernel; o teste de bloqueio será ignorado.
```

Esse aviso não significa que a compilação falhou. Ele indica que o kernel foi iniciado sem o BPF LSM na lista de módulos de segurança ativos.

### 11. Encerre e limpe o laboratório

Siga esta ordem para encerrar:

1. No Terminal 2, que está lendo `trace_pipe`, pressione `Ctrl+C`.
2. Volte ao Terminal 1, que ainda mostra a mensagem para pressionar Enter.
3. Pressione Enter no Terminal 1.

O Makefile removerá:

- programas e links fixados em `/sys/fs/bpf/ebpf_lab1`;
- `kprobe_exec.bpf.o`;
- `lsm_block.bpf.o`;
- `vmlinux.h` gerado durante a execução.

## Confirmar a limpeza

Depois de encerrar o laboratório, execute no Terminal 3:

```bash
sudo test ! -e /sys/fs/bpf/ebpf_lab1 && echo "Lab 1 removido com sucesso"
```

## Solução de problemas

### `Permission denied` durante `make setup` ou `make test`

Execute novamente e informe a senha do usuário Ubuntu quando `sudo` solicitar:

```bash
make setup
make test
```

### `/sys/kernel/btf/vmlinux não está disponível`

No PowerShell do Windows, atualize e reinicie o WSL:

```powershell
wsl --update
wsl --shutdown
```

Abra novamente o Ubuntu e confirme:

```bash
ls -lh /sys/kernel/btf/vmlinux
```

### `failed to create dir '/sys/fs/bpf/...'`

Verifique se o BPF filesystem está montado:

```bash
mountpoint /sys/fs/bpf
```

Se necessário, monte-o manualmente:

```bash
sudo mkdir -p /sys/fs/bpf
sudo mount -t bpf bpf /sys/fs/bpf
```

Depois, execute novamente:

```bash
make setup
make test
```

### O Kprobe não consegue encontrar `__x64_sys_execve`

Confira o símbolo disponível no kernel:

```bash
sudo grep -E ' (__x64_sys_execve|sys_execve)$' /proc/kallsyms
```

Este laboratório espera encontrar `__x64_sys_execve`. Se apenas outro símbolo aparecer, o hook definido em `kprobe_exec.bpf.c` precisará ser adaptado para esse kernel.

### `trace_pipe` não existe

Confira se `tracefs` está montado:

```bash
mount | grep tracefs
```

Se não estiver, execute:

```bash
sudo mkdir -p /sys/kernel/tracing
sudo mount -t tracefs tracefs /sys/kernel/tracing
```

Depois, tente novamente:

```bash
sudo cat /sys/kernel/tracing/trace_pipe
```
