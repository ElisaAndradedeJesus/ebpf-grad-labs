---

### 2. Laboratório 1: Tipos de Programas eBPF Neste laboratório, validamos a teoria rodando programas no nível do Host para entender a diferença entre Observabilidade e Segurança.

**`Lab1-Tipos_eBPF/README.md`**
```markdown
# Lab 1: Kprobes e LSM na Prática

Neste laboratório, vamos explorar duas categorias fundamentais de eBPF que não lidam com pacotes de rede, mas sim com o comportamento do sistema operacional.

## 1. Observabilidade: Kprobes (Kernel Probes)
O `BPF_PROG_TYPE_KPROBE` permite anexar código eBPF a quase qualquer função interna do Kernel[cite: 13]. O objetivo aqui não é mexer no pacote ou alterar o fluxo, mas sim "ouvir" o que o sistema está fazendo[cite: 46].
* **Contexto:** O contexto `pt_regs` permite ler os registradores da CPU (os argumentos que foram passados para a função original)[cite: 48].
* **Analogia:** Pense no Kprobe como **um microfone escondido em uma sala**[cite: 72].
* **Uso Prático:** É excelente para *debugging* profundo, pois permite espionar qualquer função, mesmo que ela não tenha sido planejada pelos desenvolvedores do Linux para ser rastreada[cite: 50].

## 2. Segurança Ativa: LSM (Linux Security Modules)
Enquanto o Kprobe apenas assiste, o `BPF_PROG_TYPE_LSM` foca em garantir que o sistema opere dentro de políticas permitidas[cite: 20]. Ele atua diretamente nos ganchos de segurança nativos do Linux[cite: 21].
* **Superpoder:** Diferente de apenas "observar", o LSM pode **vetar** a ação[cite: 99]. Se o seu código eBPF retornar um erro negativo (como `-EPERM`), a operação é bloqueada com a mensagem "Operação não permitida"[cite: 70].
* **Analogia:** Pense no LSM como **o oficial de compliance da empresa**[cite: 72]. Ele avalia o contrato antes de assiná-lo.
* **Uso Prático:** Impedir montagem de discos não autorizados, bloquear execução de binários espec