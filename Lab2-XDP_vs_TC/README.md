# Lab 2: Filtros de Rede (XDP vs. Traffic Control)

[cite_start]Nesta categoria, a diferença está na profundidade em que o programa opera no stack de rede[cite: 34].

* [cite_start]**XDP:** É o ponto mais precoce possível[cite: 36]. [cite_start]O contexto `xdp_md` contém apenas ponteiros para o início e fim dos dados brutos[cite: 36]. [cite_start]Seu "superpoder" é rejeitar pacotes antes do Kernel gastar 1 centavo de CPU com eles[cite: 38]. [cite_start]Permite apenas tráfego de entrada (*Ingress*)[cite: 129].
* [cite_start]**TC (Traffic Control):** Diferente do XDP, ele atua no tráfego de entrada e saída e trabalha com o contexto `sk_buff`, que já possui metadados processados pelo kernel[cite: 9].

Para ilustrar isso, usaremos o Containerlab para simular o tráfego entre `h1` e `h2` e anexaremos os programas eBPF nas interfaces dos containers.