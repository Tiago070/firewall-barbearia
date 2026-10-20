# Firewall Linux para a TIBarber

## Visão geral

A TIBarber é uma barbearia fictícia cujo sistema de agendamento funciona em servidor local.
O laboratório simula a separação entre a LAN da recepção e a DMZ com aplicação web e banco PostgreSQL.
Um firewall Linux com iptables aplica política deny-by-default entre as redes.

## Pré-requisitos

- Docker Engine.
- Plugin Docker Compose, para usar o comando `docker compose`.
- PowerShell no Windows, ou um terminal Linux/macOS.

## Como executar

No PowerShell, a partir da pasta do repositório:

```powershell
Copy-Item .env.example .env
docker compose up -d --build
docker compose ps
```

No Linux ou macOS, a partir da pasta do repositório:

```sh
cp .env.example .env
docker compose up -d --build
docker compose ps
```

O comando `docker compose ps` deve mostrar os containers `firewall`, `cliente`, `dmz-web` e `dmz-db` em execução.

## Topologia

```text
  LAN: 172.16.0.0/24                          DMZ: 172.20.0.0/24
+---------------------------+              +---------------------------+
| cliente                   |              | dmz-web                   |
| 172.16.0.10               |              | 172.20.0.10               |
|                           |              +---------------------------+
| firewall: 172.16.0.254    |              | dmz-db                    |
+-------------+-------------+              | 172.20.0.20               |
              |                            |                           |
              +------ firewall ------------| firewall: 172.20.0.254    |
               rota estática               +---------------------------+
```

| Rede | Serviço | Endereço IP |
|---|---|---|
| LAN (`172.16.0.0/24`) | cliente | `172.16.0.10` |
| LAN (`172.16.0.0/24`) | firewall | `172.16.0.254` |
| DMZ (`172.20.0.0/24`) | dmz-web (Nginx) | `172.20.0.10` |
| DMZ (`172.20.0.0/24`) | dmz-db (PostgreSQL) | `172.20.0.20` |
| DMZ (`172.20.0.0/24`) | firewall | `172.20.0.254` |

O cliente e o dmz-web têm rotas estáticas para a outra rede pelo firewall. O banco está na mesma rede que o dmz-web; a comunicação entre eles não atravessa o firewall.

## Resumo das regras do firewall

| Tráfego | Ação |
|---|---|
| Políticas padrão de INPUT e FORWARD | DROP |
| Política padrão de OUTPUT | ACCEPT |
| Loopback destinado ao firewall | ACCEPT |
| Pacotes INVALID em INPUT e FORWARD | DROP |
| Conexões ESTABLISHED,RELATED em INPUT e FORWARD | ACCEPT |
| LAN para dmz-web, TCP destino 80, estado NEW | ACCEPT |
| LAN para PostgreSQL (`172.20.0.20`), TCP destino 5432 | DROP |
| DMZ para LAN, conexões novas | DROP |
| LAN para dmz-web, ICMP echo-request | ACCEPT |
| Outros tráfegos encaminhados não liberados | DROP pela política de FORWARD |

## Testes manuais

Execute os comandos a partir da pasta do repositório. Os comandos de teste são os mesmos no PowerShell e no terminal Linux/macOS.

### Testes positivos

HTTP deve retornar o código `200`:

```sh
docker compose exec cliente curl -sS -o /dev/null -w "%{http_code}\n" http://dmz-web
```

Resultado esperado:

```text
200
```

Ping à aplicação web deve receber respostas:

```sh
docker compose exec cliente ping -c 2 dmz-web
```

### Testes negativos

A porta 5432 do banco deve aparecer como `filtered`:

```sh
docker compose exec cliente nmap -Pn -p 5432 172.20.0.20
```

A porta 8080 do dmz-web deve aparecer como `filtered`:

```sh
docker compose exec cliente nmap -Pn -p 8080 172.20.0.10
```

Uma tentativa de wget do dmz-web para o cliente deve falhar por timeout, pois a conexão nova da DMZ para a LAN é descartada:

```sh
docker compose exec dmz-web wget -T 3 -O - http://172.16.0.10
```

O ping para `172.16.0.254`, endereço do firewall na LAN, falha por desenho: o pacote é destinado ao próprio firewall e a política de INPUT é DROP. Não use esse ping como teste positivo.

Se executar traceroute até a DMZ, o primeiro salto deve ser `172.16.0.254` e os seguintes aparecem como `* * *`: os probes UDP posteriores são descartados pela política DROP de FORWARD.

Comando para observar esse caminho:

```sh
docker compose exec cliente traceroute -m 5 -w 1 dmz-web
```

### Teste de isolamento da rota

Remova a rota do cliente para a DMZ e faça a solicitação HTTP:

```sh
docker compose exec cliente ip route del 172.20.0.0/24
docker compose exec cliente sh -c 'curl -sS -I --connect-timeout 3 http://dmz-web; echo "exit=$?"'
```

Resultado esperado: o `curl` termina por timeout e mostra `exit=28`. Para restaurar a rota, reinicie o cliente:

```sh
docker compose restart cliente
```

### Gerar evidências

Execute os comandos a partir da raiz do repositório. No Windows, use o Git Bash:

```sh
bash tests/coletar-evidencias.sh antes
bash tests/coletar-evidencias.sh depois
```

## Contadores do firewall

Para consultar as regras da chain FORWARD e os respectivos contadores:

```sh
docker compose exec firewall iptables -L FORWARD -n -v --line-numbers
```

Execute esse comando antes e depois dos testes negativos. O incremento dos contadores da regra de bloqueio do PostgreSQL ou da política DROP ajuda a observar os pacotes descartados pelo firewall.

## Encerrar o ambiente

Para parar e remover os containers, redes e volumes do Compose:

```sh
docker compose down -v
```

## Relatório

Consulte o [relatório do projeto](docs/relatorio.md) para a definição do case, diagnóstico, matriz de regras e metodologia de validação.
