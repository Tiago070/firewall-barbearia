# Visão geral

Ambiente inicial para simular uma rede segmentada de uma barbearia com Docker Compose. Nesta etapa, o firewall encaminha pacotes entre LAN e DMZ, mas ainda não aplica regras iptables.

# Pré-requisitos

- Docker Engine com o plugin Docker Compose.
- Arquivo `.env` criado a partir do `.env.example`.

# Como executar

Copie o arquivo de exemplo para `.env` e inicie os serviços:

```powershell
Copy-Item .env.example .env
docker compose up -d --build
```

No Linux ou macOS:

```sh
cp .env.example .env
docker compose up -d --build
```

# Topologia

| Rede | Sub-rede | Serviços |
| --- | --- | --- |
| lan | 172.16.0.0/24 | cliente: 172.16.0.10; firewall: 172.16.0.254 |
| dmz | 172.20.0.0/24 | dmz-web: 172.20.0.10; dmz-db: 172.20.0.20; firewall: 172.20.0.254 |

O cliente e o servidor web usam rotas estáticas pelo firewall. O `dmz-db` não tem rota para a LAN de propósito, pois nenhum tráfego da LAN para o banco é permitido.

# Testes

```powershell
docker compose exec cliente ping -c 2 172.16.0.254
docker compose exec cliente traceroute -m 5 -w 1 dmz-web
docker compose exec cliente curl -fsS http://dmz-web
```

No `traceroute`, o primeiro salto esperado é `172.16.0.254` e o destino é `172.20.0.10`. Nesta etapa inicial, o encaminhamento ainda não tem filtragem.

# Estrutura do repositório

```text
.
├── cliente/
├── dmz/
│   ├── db/
│   └── web/
├── docs/
│   └── evidencias/
├── firewall/
├── tests/
├── .env.example
└── docker-compose.yml
```
