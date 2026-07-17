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
- `run_and_test.sh`: prepara, compila, carrega, testa e remove os programas.

O script gera `vmlinux.h`, compila os programas e monta o BPF filesystem em `/sys/fs/bpf` caso ele ainda não esteja montado. Os arquivos gerados são removidos ao final.

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

### 2. Conceda permissão de execução ao script

Este comando precisa ser executado apenas na primeira vez:

```bash
chmod +x run_and_test.sh
```

### 3. Execute o script

O carregamento de programas eBPF e a montagem do BPF filesystem exigem privilégios administrativos:

```bash
sudo ./run_and_test.sh
```

O script deve:

1. verificar a disponibilidade de BTF;
2. preparar `/sys/fs/bpf`;
3. gerar `vmlinux.h`;
4. compilar os dois programas eBPF;
5. carregar e anexar o Kprobe;
6. verificar se BPF LSM está ativo;
7. aguardar antes de remover os programas.

Não pressione Enter quando aparecer a mensagem final. Deixe esse terminal aberto enquanto realiza o teste do Kprobe.

### 4. Observe os eventos do Kprobe

Abra um segundo terminal Ubuntu e execute:

```bash
sudo cat /sys/kernel/tracing/trace_pipe
```

Se esse caminho não existir, tente:

```bash
sudo cat /sys/kernel/debug/tracing/trace_pipe
```

Deixe o comando em execução. Em um terceiro terminal Ubuntu, execute alguns programas:

```bash
ls
date
whoami
```

No terminal que está lendo `trace_pipe`, devem aparecer mensagens semelhantes a:

```text
KPROBE: Processo 'ls' executado!
KPROBE: Processo 'date' executado!
KPROBE: Processo 'whoami' executado!
```

O nome observado pode variar porque outros processos também executam programas enquanto o Kprobe está ativo.

### 5. Interprete o teste do BPF LSM

O script consulta `/sys/kernel/security/lsm` antes de carregar o programa de segurança.

Se BPF LSM estiver ativo, o script carregará o programa e testará `curl --version`. O resultado esperado é:

```text
SUCESSO: a execução do curl foi bloqueada pelo BPF LSM.
```

Se BPF LSM não estiver ativo, o laboratório mostrará um aviso e continuará apenas com o Kprobe:

```text
AVISO: BPF LSM não está ativo neste kernel; o teste de bloqueio será ignorado.
```

Esse aviso não significa que a compilação falhou. Ele indica que o kernel foi iniciado sem o BPF LSM na lista de módulos de segurança ativos.

### 6. Encerre e limpe o laboratório

No terminal que está lendo `trace_pipe`, pressione `Ctrl+C`.

Depois, volte ao primeiro terminal e pressione Enter. O script removerá:

- programas e links fixados em `/sys/fs/bpf/ebpf_lab1`;
- `kprobe_exec.bpf.o`;
- `lsm_block.bpf.o`;
- `vmlinux.h` gerado durante a execução.

## Confirmar a limpeza

Depois de encerrar o script, execute:

```bash
sudo test ! -e /sys/fs/bpf/ebpf_lab1 && echo "Lab 1 removido com sucesso"
```

## Solução de problemas

### `Execute este laboratório com: sudo ./run_and_test.sh`

O script foi iniciado sem os privilégios necessários. Execute:

```bash
sudo ./run_and_test.sh
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
sudo ./run_and_test.sh
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
