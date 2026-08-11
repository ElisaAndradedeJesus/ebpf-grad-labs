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

## Habilitar o BPF LSM no WSL 2

Este laboratório possui duas partes. O Kprobe funciona sem o BPF LSM, mas o
experimento que bloqueia a execução do `curl` exige que o LSM `bpf` esteja
ativo desde a inicialização do kernel.

### 1. Verifique os LSMs ativos

Primeiro, confirme que o `securityfs` está montado:

```bash
sudo mkdir -p /sys/kernel/security
mountpoint -q /sys/kernel/security || \
sudo mount -t securityfs securityfs /sys/kernel/security
```

Consulte os Linux Security Modules ativos:

```bash
sudo cat /sys/kernel/security/lsm
```

Se a saída contiver `bpf`, nenhuma alteração é necessária. Continue em
[Executar o laboratório](#executar-o-laboratório).

Se `bpf` não aparecer, siga as próximas etapas.

### 2. Verifique o suporte do kernel

O BPF LSM precisa estar incluído na configuração usada para compilar o kernel:

```bash
zgrep '^CONFIG_BPF_LSM=' /proc/config.gz 2>/dev/null || \
grep '^CONFIG_BPF_LSM=' /boot/config-"$(uname -r)" 2>/dev/null
```

O resultado esperado é:

```text
CONFIG_BPF_LSM=y
```

Se nenhum dos arquivos de configuração estiver disponível, isso não prova que
o recurso está ausente. Atualize o WSL pelo PowerShell:

```powershell
wsl --update
wsl --shutdown
```

Abra novamente o Ubuntu e repita a verificação.

Se o resultado for:

```text
# CONFIG_BPF_LSM is not set
```

o kernel atual não possui suporte ao BPF LSM. Nesse caso, será necessário
utilizar uma versão atualizada do kernel do WSL ou um kernel personalizado
compilado com `CONFIG_BPF_LSM=y`.

### 3. Ative o BPF LSM na inicialização

> Esta configuração é realizada no Windows e se aplica globalmente às
> distribuições executadas com WSL 2.

No PowerShell, abra o arquivo `.wslconfig`:

```powershell
notepad $env:USERPROFILE\.wslconfig
```

Se o arquivo não existir, o Bloco de Notas perguntará se deseja criá-lo.

Adicione:

```ini
[wsl2]
kernelCommandLine=lsm=landlock,lockdown,yama,integrity,apparmor,bpf
```

Se o arquivo já possuir uma seção `[wsl2]`, não crie outra: adicione somente
a propriedade `kernelCommandLine` dentro da seção existente.

Se já existir uma propriedade `kernelCommandLine`, preserve os outros
parâmetros. Caso ela ainda não possua `lsm=`, acrescente o parâmetro na mesma
linha, separado por espaço. Caso já possua `lsm=`, não crie um segundo:
acrescente `bpf` à lista existente.

> O parâmetro `lsm=` define a lista de módulos de segurança habilitados durante
> a inicialização. Não utilize apenas `lsm=bpf`, pois isso pode retirar outros
> mecanismos de segurança da lista.

Salve e feche o arquivo.

### 4. Reinicie o WSL 2

Feche trabalhos em execução nas distribuições WSL. Em seguida, execute no
PowerShell:

```powershell
wsl --shutdown
```

Esse comando encerra todas as distribuições WSL abertas. Depois, abra
novamente o Ubuntu.

### 5. Confirme a ativação

No Ubuntu, verifique se o parâmetro foi recebido pelo kernel:

```bash
cat /proc/cmdline
```

A saída deve conter:

```text
lsm=landlock,lockdown,yama,integrity,apparmor,bpf
```

O comando `wsl --shutdown` encerra o kernel, e montagens realizadas manualmente
podem não permanecer depois que o WSL for iniciado novamente. Por isso,
verifique o `securityfs` outra vez. O bloco abaixo só realiza a montagem quando
ela ainda não existe:

```bash
sudo mkdir -p /sys/kernel/security

if mountpoint -q /sys/kernel/security; then
    echo "securityfs já está montado."
else
    sudo mount -t securityfs securityfs /sys/kernel/security
    echo "securityfs foi montado."
fi
```

Confira novamente os LSMs ativos:

```bash
sudo cat /sys/kernel/security/lsm
```

A lista deve conter `bpf`. Por exemplo:

```text
capability,landlock,lockdown,yama,integrity,apparmor,bpf
```

O módulo `capability` pode aparecer automaticamente mesmo sem estar escrito no
parâmetro `lsm=`.

Agora as duas partes do laboratório poderão ser executadas:

```bash
make setup
make attach
```

Durante `make attach`, o resultado esperado para o teste do BPF LSM é:

```text
SUCESSO: a execução do curl foi bloqueada pelo BPF LSM.
```

### Restaurar a configuração anterior

Para desfazer a ativação, abra novamente o arquivo no PowerShell:

```powershell
notepad $env:USERPROFILE\.wslconfig
```

Remova somente o parâmetro `lsm=...` adicionado por este laboratório, preserve
as demais configurações e execute:

```powershell
wsl --shutdown
```

## Arquivos do laboratório

- `kprobe_exec.bpf.c`: registra a execução de processos;
- `lsm_block.bpf.c`: tenta impedir a execução do `curl`;
- `Makefile`: prepara, compila, carrega, testa e remove os programas.

[Consulte uma explicação mais detalhada sobre os códigos eBPF aqui](CODES.md)

O Makefile gera `vmlinux.h`, compila os programas e monta `bpffs` e `securityfs`
caso ainda não estejam montados. `make attach` anexa os programas ao kernel,
`make detach` os desanexa e `make clean` remove somente os arquivos gerados.

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

### 5. Anexe os programas

Depois que a preparação terminar, carregue e anexe os programas:

```bash
make attach
```

Esse comando:

1. carrega e anexa o Kprobe;
2. verifica se BPF LSM está ativo;
3. carrega o programa BPF LSM;
4. tenta executar `curl --version` para comprovar o bloqueio;
5. mantém os programas fixados em `/sys/fs/bpf/ebpf_lab1`.

Quando aparecer a mensagem abaixo, os programas estarão anexados e continuarão
ativos mesmo depois que o comando devolver o terminal:

```text
Programas anexados. Quando terminar o experimento, execute: make detach
```

### 6. Entenda o teste com dois terminais

O teste utiliza dois terminais Ubuntu ao mesmo tempo. Cada um possui uma responsabilidade diferente:

| Terminal | Responsabilidade | Comando principal |
|---|---|---|
| Terminal 1 | Anexar os programas, exibir os eventos e, ao final, desanexá-los | `make attach`, `sudo cat /sys/kernel/tracing/trace_pipe` e `make detach` |
| Terminal 2 | Executar programas para gerar eventos e confirmar o Kprobe | `ls`, `date`, `whoami` e `bpftool` |

O fluxo do experimento é:

```text
Terminal 2 executa um programa
              ↓
O kernel executa __x64_sys_execve
              ↓
O Kprobe carregado pelo Terminal 1 é acionado
              ↓
O programa eBPF escreve uma mensagem de tracing
              ↓
O Terminal 1 exibe a mensagem pelo trace_pipe
```

### 7. Terminal 1: observe os eventos do Kprobe

No mesmo Terminal 1 em que você executou `make attach`, execute:

```bash
sudo cat /sys/kernel/tracing/trace_pipe
```

Se esse caminho não existir, tente:

```bash
sudo cat /sys/kernel/debug/tracing/trace_pipe
```

Deixe esse comando em execução. O terminal ficará aparentemente parado enquanto aguarda novas mensagens do kernel. Isso é o comportamento esperado.

### 8. Terminal 2: gere eventos de execução

Abra um segundo terminal Ubuntu e execute, um de cada vez:

```bash
ls
date
whoami
```

Esses comandos iniciam novos programas. Cada inicialização passa pela função `__x64_sys_execve`, na qual o Kprobe está anexado.

Volte ao Terminal 1. Devem aparecer mensagens semelhantes a:

```text
KPROBE: Processo 'bash' executado!
KPROBE: Processo 'sudo' executado!
KPROBE: Processo 'grep' executado!
```

O Kprobe observa todas as chamadas a `execve` realizadas pelo sistema enquanto estiver ativo. Portanto, os eventos gerados por `ls`, `date` e `whoami` podem aparecer misturados a eventos de outros processos e serviços do ambiente.

O programa usa `bpf_get_current_comm()` no início de `execve`. Nesse momento, o processo ainda pode ter o nome do programa anterior, como `bash`, antes de ser substituído pelo novo executável. Por isso, o texto entre aspas nem sempre será `ls`, `date` ou `whoami`, mesmo quando esses comandos tiverem gerado o evento.

### 9. Confirme o programa com bpftool

Ainda no Terminal 2, confirme que o programa está carregado no kernel:

```bash
sudo bpftool prog list | grep -A 4 trace_exec
```

A saída deve identificar `trace_exec` como um programa do tipo `kprobe`.

O teste do Kprobe é considerado bem-sucedido quando existem as duas evidências:

1. `bpftool` mostra o programa `trace_exec` carregado;
2. o Terminal 1 mostra mensagens geradas quando os comandos do Terminal 2 são executados.

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

### 11. Desanexe os programas

Siga esta ordem para encerrar:

1. No Terminal 1, que está lendo `trace_pipe`, pressione `Ctrl+C`.
2. No mesmo terminal, execute:

```bash
make detach
```

Esse comando remove do kernel:

- programas e links fixados em `/sys/fs/bpf/ebpf_lab1`.

Os arquivos `kprobe_exec.bpf.o`, `lsm_block.bpf.o` e `vmlinux.h` permanecerão
no diretório. Assim, você pode executar `make attach` novamente sem repetir
`make setup`.

Para confirmar que os programas foram desanexados, execute no Terminal 1:

```bash
sudo test ! -e /sys/fs/bpf/ebpf_lab1 && echo "Programas eBPF desanexados com sucesso"
```

## Limpar os arquivos gerados

Execute `make clean` quando terminar os testes e não precisar mais repetir o
experimento:

```bash
make clean
```

Esse comando remove:

- `kprobe_exec.bpf.o`;
- `lsm_block.bpf.o`;
- `vmlinux.h`.

Se os programas ainda estiverem anexados, `make clean` não removerá os arquivos
e solicitará que você execute `make detach` primeiro.

Para confirmar que a limpeza funcionou:

```bash
sudo test ! -e /sys/fs/bpf/ebpf_lab1 && \
test ! -e kprobe_exec.bpf.o && \
test ! -e lsm_block.bpf.o && \
test ! -e vmlinux.h && \
echo "Lab 1 removido com sucesso"
```

## Solução de problemas

### `Permission denied` durante `make setup`, `make attach` ou `make detach`

Execute novamente e informe a senha do usuário Ubuntu quando `sudo` solicitar:

```bash
make setup
make attach
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
make attach
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
