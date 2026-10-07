# Contexto do projeto
Trabalho acadêmico de Segurança da Informação (IF Goiano, Campus Ceres). Tema: Firewall Linux com Netfilter/iptables simulado em Docker Compose. Trabalho individual, avaliado também por apresentação oral, então todo código deve ser simples, comentado e explicável.

# Cenário (case)
Barbearia fictícia com sistema de agendamento hospedado em servidor local. Dados pessoais de clientes (LGPD) ficam em PostgreSQL. Todos os dados são fictícios.

# Topologia (não alterar sem me avisar)
- Rede lan: 172.16.0.0/24 (bridge). Container cliente: 172.16.0.10 (Alpine com curl, nmap, netcat, traceroute).
- Rede dmz: 172.20.0.0/24 (bridge). dmz-web (Nginx): 172.20.0.10. dmz-db (PostgreSQL): 172.20.0.20.
- Container firewall (Alpine com iptables): 172.16.0.254 na lan e 172.20.0.254 na dmz. É o único caminho entre lan e dmz.
- Cliente e dmz-web recebem rotas estáticas apontando para o firewall.

# Regras de código
- Shell POSIX (#!/bin/sh), compatível com Alpine/busybox.
- Comentários em português, com acentuação correta, explicando o PORQUÊ de cada linha relevante.
- Firewall: iptables com política DROP em INPUT e FORWARD e OUTPUT ACCEPT. Ordem: flush completo, políticas, loopback, INVALID DROP, ESTABLISHED,RELATED ACCEPT, regras explícitas. Usar -m conntrack --ctstate.
- Tráfego entre redes é filtrado na chain FORWARD, nunca em INPUT ou OUTPUT.
- Proibido: privileged: true, network_mode: host, publicar portas no host (ports:), política ACCEPT em INPUT/FORWARD, senhas escritas no docker-compose.yml (usar .env).
- NET_ADMIN somente nos containers que precisam ajustar rota (firewall, cliente, dmz-web), nunca no dmz-db.
- Não inventar flags ou opções: se não tiver certeza de um parâmetro do iptables, diga que não tem certeza.

# Estilo de resposta
- Antes do código, explique em 3 a 5 linhas a ideia. Depois do código, diga como testar.
- Não usar travessão nos textos. Usar acentuação correta.
- Mensagens de commit em Conventional Commits, em português (feat:, docs:, test:, chore:).