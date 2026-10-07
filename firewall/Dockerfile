FROM alpine:3.22

# O iproute2 permite inspecionar interfaces e rotas nesta etapa inicial.
# O iptables e o tcpdump ficam disponíveis para as etapas futuras de filtragem e diagnóstico.
# O coreutils fornece `sleep infinity`, solicitado para manter o contêiner ativo.
RUN apk add --no-cache coreutils iproute2 iptables tcpdump

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
