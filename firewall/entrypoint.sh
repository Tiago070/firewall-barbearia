#!/bin/sh
set -eu

# Exibe as interfaces e rotas para confirmar a topologia antes de configurar regras.
ip addr
ip route

# Mantém o contêiner ativo sem aplicar regras de firewall nesta etapa.
exec sleep infinity
