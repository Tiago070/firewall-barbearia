FROM alpine:3.22

# O coreutils fornece o sleep com suporte ao argumento infinity usado para manter o contêiner ativo.
# O curl testa requisições HTTP e a resposta dos serviços acessíveis pela rede.
# O nmap verifica quais hosts e portas respondem durante os testes de conectividade.
# O netcat-openbsd fornece nc para testar conexões TCP e UDP a portas específicas.
# O traceroute identifica os saltos percorridos pelos pacotes até o destino.
RUN apk add --no-cache coreutils curl nmap netcat-openbsd traceroute
