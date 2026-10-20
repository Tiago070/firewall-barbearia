#!/bin/sh
# Coleta evidências reais do ambiente e grava o resultado em docs/evidencias/.
#
# Uso, na raiz do repositório (Git Bash no Windows, Linux ou macOS):
#   bash tests/coletar-evidencias.sh antes    # firewall SEM regras (abertas manualmente)
#   bash tests/coletar-evidencias.sh depois   # firewall com as regras do entrypoint.sh
#
# Pré-requisito: o ambiente já está de pé (docker compose up -d --build).
# Este script não altera nenhum arquivo do projeto, só grava o log em docs/evidencias/.

# Evita que o Git Bash converta caminhos como /bin/sh em caminhos do Windows.
export MSYS_NO_PATHCONV=1

FASE="${1:-depois}"
case "$FASE" in
  antes|depois) ;;
  *) echo "Uso: $0 antes|depois"; exit 1 ;;
esac

ARQ="docs/evidencias/${FASE}-das-regras.txt"

EM_EXECUCAO=$(docker compose ps --status running --services | wc -l | tr -d ' ')
if [ "$EM_EXECUCAO" -lt 4 ]; then
  echo "Os 4 serviços precisam estar em execução. Rode: docker compose up -d --build"
  exit 1
fi

# Mostra o comando, executa e registra o código de saída.
cmd() {
  echo ""
  echo "### $1"
  shift
  printf '$ %s\n' "$*"
  "$@"
  echo "[código de saída: $?]"
}

# Mostra os contadores de uma chain. Lido logo após cada teste, permite atribuir o
# incremento de pacotes à regra responsável (compare com o snapshot anterior).
contadores() {
  cmd "Contadores da chain $1 após o teste anterior" \
    docker compose exec -T firewall iptables -L "$1" -n -v -x --line-numbers
}

# Reinicia o cliente: encerra o responder do teste T6 e recria a rota estática pelo firewall.
reiniciar_cliente() {
  docker compose restart cliente >/dev/null 2>&1
  sleep 3
}

# Roda ao sair, mesmo se o script for interrompido: devolve o ambiente ao estado normal.
restaurar() {
  reiniciar_cliente
  if [ "$FASE" = "antes" ]; then
    # Recria o firewall para recarregar as regras do entrypoint.sh.
    docker compose up -d --force-recreate firewall >/dev/null 2>&1
    sleep 3
    echo "Firewall recriado: regras do entrypoint.sh recarregadas."
  fi
}

executar() {
  trap restaurar EXIT
  trap 'exit 1' INT TERM

  echo "# Evidências: firewall ${FASE} das regras"
  echo "Gerado em: $(date '+%Y-%m-%d %H:%M:%S %z')"

  if [ "$FASE" = "antes" ]; then
    # Simula o firewall sem regras: remove as regras e deixa todas as políticas em ACCEPT.
    # Só afeta o container firewall; o computador não é alterado.
    cmd "Abrindo o firewall (sem regras, políticas ACCEPT)" \
      docker compose exec -T firewall sh -c "iptables -F; iptables -P INPUT ACCEPT; iptables -P FORWARD ACCEPT; iptables -P OUTPUT ACCEPT"
  fi

  cmd "Containers em execução" docker compose ps
  cmd "Regras no início" docker compose exec -T firewall iptables -L -n -v -x --line-numbers

  cmd "T1 HTTP do cliente para o dmz-web" \
    docker compose exec -T cliente curl -sS --connect-timeout 3 -o /dev/null -w "HTTP %{http_code}\n" http://dmz-web
  cmd "T2 ping do cliente para o dmz-web" \
    docker compose exec -T cliente ping -c 2 -W 2 dmz-web
  contadores FORWARD
  cmd "T3 portas 80 e 8080 do dmz-web" \
    docker compose exec -T cliente nmap -Pn -p 80,8080 --max-retries 1 172.20.0.10
  contadores FORWARD
  cmd "T4 porta 5432 do banco" \
    docker compose exec -T cliente nmap -Pn -p 5432 --max-retries 1 172.20.0.20
  contadores FORWARD
  cmd "T5 ping do cliente para o firewall" \
    docker compose exec -T cliente ping -c 2 -W 2 172.16.0.254
  contadores INPUT
  cmd "T6a traceroute do cliente para o dmz-web" \
    docker compose exec -T cliente traceroute -m 3 -w 1 dmz-web

  # T6: sentido DMZ para LAN. O cliente passa a responder na porta 8080 (HTTP mínimo),
  # para que "conexão bloqueada" (timeout) seja distinguível de "conexão aceita" (resposta ok).
  cmd "T6b iniciando responder na porta 8080 do cliente" \
    docker compose exec -T -d cliente sh -c "while true; do printf 'HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok' | nc -l 8080; done"
  sleep 2
  cmd "T6c wget do dmz-web para o cliente (DMZ para LAN)" \
    docker compose exec -T dmz-web wget -T 3 -q -O- http://172.16.0.10:8080
  contadores FORWARD
  reiniciar_cliente

  # T7: isolamento. Sem a rota pelo firewall, o cliente não alcança a DMZ.
  cmd "T7a removendo a rota do cliente para a DMZ" \
    docker compose exec -T cliente ip route del 172.20.0.0/24
  cmd "T7b curl sem a rota" \
    docker compose exec -T cliente sh -c 'curl -sS -I --connect-timeout 3 http://dmz-web; echo "exit=$?"'
  reiniciar_cliente
  cmd "T7c curl após restaurar a rota" \
    docker compose exec -T cliente curl -sS --connect-timeout 3 -o /dev/null -w "HTTP %{http_code}\n" http://dmz-web

  cmd "Regras e contadores no final" docker compose exec -T firewall iptables -L -n -v -x --line-numbers
}

executar 2>&1 | tee "$ARQ"
echo ""
echo "Log gravado em $ARQ"