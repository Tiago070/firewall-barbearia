FROM alpine:3.22

# Essas ferramentas permitem testar conectividade e observar o caminho do tráfego.
# O coreutils fornece `sleep infinity` de forma compatível com o comando do Compose.
RUN apk add --no-cache coreutils curl nmap netcat-openbsd traceroute
