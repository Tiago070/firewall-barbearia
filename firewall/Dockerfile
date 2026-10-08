FROM alpine:3.22

# O coreutils fornece o sleep com suporte ao argumento infinity usado para manter o contêiner ativo.
# O iproute2 fornece ip addr e ip route para inspecionar interfaces, endereços e rotas.
# O iptables prepara o utilitário para configurar regras Netfilter em uma etapa posterior.
# O tcpdump permite capturar pacotes e diagnosticar o tráfego entre as redes.
RUN apk add --no-cache coreutils iproute2 iptables tcpdump

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
