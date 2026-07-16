# Lab 3: Firewall Dinâmico com eBPF Maps

[cite_start]O uso de Maps transforma o eBPF de um script isolado em uma aplicação de rede completa, permitindo que o programa "lembre" de IPs ou armazene dados[cite: 118]. [cite_start]Neste exemplo, o programa XDP não apenas olha o pacote, mas consulta uma Hash Map (preenchida pelo Userspace) para decidir se deve banir um IP em tempo real[cite: 79]. [cite_start]Isso é a base de sistemas como o Cloudflare Magic Transit[cite: 80].

* `h1`: Atua como o Firewall com XDP.
* `h2`: É o atacante (Será inserido no Mapa para ser banido).
* `h3`: É o cliente legítimo.