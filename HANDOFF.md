# Continuidade do projeto

Este arquivo preserva o contexto necessário para continuar o trabalho em outro computador ou em uma nova conversa com o Codex.

Ele não substitui os READMEs dos laboratórios e não autoriza mudanças automáticas. Informações classificadas como pendentes ou ideias devem ser confirmadas com Elisa antes de qualquer alteração.

Última atualização: 24 de julho de 2026.

## Por que este documento existe

As conversas locais iniciadas pelo Codex no VS Code não acompanham automaticamente o projeto quando ele é aberto em outro computador ou em uma nova conversa. O Git sincroniza os arquivos e o histórico de commits, mas não preserva todo o contexto discutido durante o desenvolvimento: decisões didáticas, problemas já encontrados, preferências de trabalho e tarefas que ainda não foram concluídas.

O `HANDOFF.md` funciona como um documento de passagem de contexto. Sua função é permitir que Elisa ou uma nova conversa com o Codex entendam rapidamente:

- qual é o objetivo do projeto;
- quais decisões já foram confirmadas;
- qual é o estado conhecido de cada laboratório;
- quais tarefas ainda precisam ser executadas;
- quais assuntos foram apenas sugeridos e ainda dependem de decisão;
- quais cuidados devem ser respeitados antes de modificar o repositório.

Esse arquivo deve ser consultado no começo de uma nova conversa e comparado com o estado atual do Git. Ele registra o contexto conhecido no momento da última atualização, mas não é uma fonte automática de verdade: commits posteriores, testes novos e decisões de Elisa podem torná-lo desatualizado.

Sempre que uma mudança importante for concluída ou uma decisão relevante for tomada, o documento pode ser atualizado junto com o projeto. Ele não deve conter senhas, credenciais, dados pessoais, saídas temporárias extensas nem detalhes que já estejam suficientemente explicados nos READMEs. Sua finalidade é preservar decisões e continuidade, não duplicar toda a documentação técnica.

## Objetivo confirmado

Construir um material didático de eBPF composto por um README principal e laboratórios práticos.

O material é destinado a alunos com pouca experiência em eBPF e deve:

- funcionar nas máquinas Windows 11 do curso usando WSL 2;
- usar Containerlab nos experimentos que precisam de topologias de rede;
- continuar compreensível para usuários de Linux;
- permitir que o aluno veja o comportamento do eBPF durante os testes;
- apresentar explicações pontuais, saídas técnicas completas e interpretações didáticas;
- manter a preparação, os testes e a limpeza como responsabilidades claramente identificáveis.

## Organização decidida

- O README principal concentra a introdução geral ao eBPF e a preparação do ambiente comum.
- Cada laboratório explica um uso específico de eBPF e seus testes.
- Os Makefiles automatizam tarefas repetitivas, mas precisam ser comentados e explicados para não esconder o conteúdo estudado.
- Os comandos dos Makefiles devem ter nomes que indiquem sua responsabilidade.
- As mensagens de erro devem explicar o que falhou e orientar como corrigir.
- A limpeza do ambiente deve ser ensinada explicitamente com `make clean`.
- Arquivos compilados `*.o` e o `vmlinux.h` gerado localmente não devem entrar no Git.

## Preferências de colaboração da Elisa

- Não alterar arquivos quando ela pedir apenas análise, opinião ou planejamento.
- Não transformar sugestões do Codex em decisões da Elisa.
- Antes de uma alteração material, explicar o que será feito e por quê.
- Preservar saídas técnicas completas quando elas tiverem valor para alunos curiosos.
- Quando houver um resumo didático no terminal, apresentá-lo depois da saída técnica, sem misturar os dois formatos.
- Antes de sugerir uma mensagem de commit, revisar as mudanças reais do Git.
- A mensagem de commit deve ser um pequeno texto pronto para o campo do VS Code, explicando o que mudou e por que mudou. Não precisa de título.
- Começar as respostas sobre o projeto com o “Checklist mestre — estado atual”.

## Estado confirmado dos laboratórios

### Lab 1 — tipos de programas eBPF

Tema: comparação entre Kprobe e BPF LSM.

Estado conhecido:

- foi executado com sucesso no WSL 2;
- o Kprobe foi carregado e observado com `trace_pipe`;
- no kernel testado, o BPF LSM não estava ativo e essa limitação foi informada pelo laboratório;
- o experimento usa três terminais e o README explica a função de cada um;
- o relatório automático que aparecia cedo demais foi removido;
- existe um comentário interno no topo do README registrando uma mudança futura desejada.

Mudança futura registrada, mas ainda não implementada:

- não limpar automaticamente o laboratório quando o teste termina;
- permitir novos testes sem repetir `make setup`;
- deixar a limpeza exclusivamente sob responsabilidade de `make clean`;
- documentar `make clean` ao final do tutorial;
- confirmar por que objetos `.o` permaneceram na pasta em uma execução observada.

Não alterar o comportamento do Lab 1 sem primeiro reler o comentário no seu README e confirmar a mudança com Elisa.

### Lab 2 — XDP versus TC

Tema: comparação entre XDP no ingresso e TC na saída.

Estado conhecido:

- foi executado com sucesso no WSL 2;
- usa XDP genérico para compatibilidade com interfaces `veth`;
- os experimentos XDP e TC foram separados no README e no Makefile;
- os antigos alvos `test-step1`, `test-step2`, `test-step3` e `test-step4` foram removidos;
- o atalho agregado `make test` foi removido;
- existem comandos específicos para linha de base, filtro e desanexação de cada tecnologia;
- a remoção do XDP utiliza o mesmo modo genérico empregado no carregamento;
- a topologia permanece ativa até o aluno executar `make clean`;
- as saídas técnicas aparecem antes do resumo didático.

O Lab 2 foi considerado funcional, mas ainda deve ser retestado nas máquinas definitivas do curso.

### Lab 3 — firewall dinâmico com eBPF Maps

Tema: atualização de uma blacklist por meio de uma Hash Map.

Estado conhecido:

- o problema conceitual da topologia anterior foi corrigido;
- a topologia atual possui `h1` e `h2`;
- `h2` usa `10.0.1.2` como origem que será bloqueada e `10.0.1.3` como origem de controle;
- os dois endereços atravessam a mesma interface `h1:eth1` e o mesmo programa XDP;
- o Makefile usa alvos semânticos: `test-baseline`, `test-empty-map`, `test-block` e `test-unblock`;
- o XDP é anexado e removido em modo genérico;
- o ID do Map do experimento é guardado temporariamente em `/tmp/ebpf-lab3-map-id`;
- o código eBPF compilou com sucesso após a reorganização;
- o README foi atualizado para explicar por que o endereço de controle valida a seletividade do Map.

Pendente:

- executar todas as etapas do Lab 3 no WSL 2 com Docker e Containerlab;
- confirmar os resultados e ajustar eventuais erros encontrados durante a execução real.

Ordem documentada para o teste:

```bash
cd Lab3-Mapas_eBPF_Firewall
make help
make setup
make test-baseline
make test-empty-map
make test-block
make test-unblock
make detach-xdp
make clean
```

## Checklist mestre — estado atual

- [x] Lab 1 testado e funcionando no ambiente usado durante o desenvolvimento.
- [x] Lab 2 corrigido, reorganizado e testado.
- [x] Problema conceitual do Lab 3 corrigido no código e na documentação.
- [ ] Executar e validar o Lab 3 completo no WSL 2.
- [ ] Aplicar, após confirmação, a mudança de ciclo de vida registrada no Lab 1.
- [ ] Revisar a documentação geral do repositório.
- [ ] Testar todos os laboratórios nas máquinas que serão utilizadas no curso.
- [ ] Polir os três laboratórios existentes antes de priorizar novos laboratórios.

## Ideias mencionadas, mas não aprovadas para implementação

- ampliar a parte teórica do README principal;
- criar novos laboratórios inspirados nos livros e materiais de referência;
- renomear as pastas para `Lab1`, `Lab2`, `Lab3` etc., preservando os temas em títulos ou descrições;
- criar um Makefile na raiz do repositório;
- usar ferramentas visuais adicionais nos experimentos.

Esses itens são possibilidades de trabalho. Não devem ser tratados como decisões nem implementados sem confirmação.

## Cuidados ao continuar

1. Execute `git status --short` antes de alterar qualquer arquivo.
2. Preserve mudanças locais que não pertencem à tarefa atual.
3. Leia o README e o Makefile do laboratório antes de modificá-lo.
4. Não altere o README principal quando o pedido estiver limitado a um laboratório.
5. Não use o sucesso de um tráfego de controle como evidência se ele não atravessar o mesmo hook eBPF do tráfego testado.
6. Não esconda a automação: explique no README e nos comentários do Makefile o que cada comando realiza.
7. Depois de alterações, valide a sintaxe, compile quando possível e informe claramente o que não pôde ser testado no ambiente local.
8. Gere a mensagem de commit somente depois de conferir o diff final.

## Como retomar em uma nova conversa

Peça ao Codex:

> Leia o `HANDOFF.md`, confira o estado atual com o Git e me diga o que está confirmado e o que ainda depende de decisão. Não altere arquivos até eu indicar a próxima tarefa.

Essa instrução obriga a nova conversa a comparar este contexto com o estado real do repositório antes de continuar.
