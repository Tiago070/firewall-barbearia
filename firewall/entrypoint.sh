#!/bin/sh
set -eu

# As sub-redes e os endereços fixos identificam os fluxos sem depender dos nomes
# das interfaces, que podem variar conforme a ordem de conexão das redes Docker.
LAN="172.16.0.0/24"
DMZ="172.20.0.0/24"
WEB="172.20.0.10"
DB="172.20.0.20"

# Etapa 1: mostra as interfaces e rotas para diagnosticar a topologia do gateway.
ip addr
ip route

# Etapa 2: remove regras e chains antigas para que a política comece em estado conhecido.
iptables -F
iptables -X
iptables -Z
iptables -t nat -F
iptables -t nat -X
iptables -t nat -Z
iptables -t mangle -F
iptables -t mangle -X
iptables -t mangle -Z

# Etapa 3: bloqueia por padrão tráfego destinado ao firewall ou encaminhado por ele.
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Etapa 4: permite loopback local, descarta pacotes sem estado válido e mantém
# respostas de conexões permitidas sem abrir novas conexões no sentido inverso.
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate INVALID -j DROP
iptables -A FORWARD -m conntrack --ctstate INVALID -j DROP

# O bloqueio do PostgreSQL é inserido antes do aceite stateful para não permitir
# tráfego de sessões antigas rastreadas que tenham como destino o banco.
iptables -I FORWARD 2 -s "$LAN" -d "$DB" -p tcp --dport 5432 -j DROP

iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Etapa 5: libera somente os novos fluxos de negócio listados para a barbearia.
iptables -A FORWARD -s "$LAN" -d "$WEB" -p tcp --dport 80 \
    -m conntrack --ctstate NEW -j ACCEPT
iptables -A FORWARD -s "$DMZ" -d "$LAN" \
    -m conntrack --ctstate NEW -j DROP
iptables -A FORWARD -s "$LAN" -d "$WEB" -p icmp --icmp-type echo-request -j ACCEPT

# Exibe as regras e seus contadores para conferir a política efetivamente carregada.
iptables -L FORWARD -n -v --line-numbers

# Mantém o contêiner ativo para executar o gateway e permitir inspeção no laboratório.
exec sleep infinity
