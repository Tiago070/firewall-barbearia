# Visão geral

Ambiente inicial para simular uma rede segmentada de uma barbearia com Docker Compose. Nesta etapa, o firewall encaminha pacotes entre LAN e DMZ, mas ainda não aplica regras iptables.

# Pré-requisitos

- Docker Engine com o plugin Docker Compose.
- Arquivo `.env` criado a partir do `.env.example`.

# Como executar

No PowerShell, copie o arquivo de exemplo e inicie os serviços:

```powershell
Copy-Item .env.example .env
docker compose up --build -d
```

# Topologia

| Rede | Sub-rede | Serviços |
| --- | --- | --- |
| lan | 172.16.0.0/24 | cliente: 172.16.0.10; firewall: 172.16.0.254 |
| dmz | 172.20.0.0/24 | dmz-web: 172.20.0.10; dmz-db: 172.20.0.20; firewall: 172.20.0.254 |

O cliente e o servidor web usam rotas estáticas pelo firewall. O PostgreSQL não recebe `NET_ADMIN`: o gateway da bridge Docker pode encaminhar as respostas por um caminho assimétrico. Na etapa de regras, deve-se configurar SNAT no firewall para que as respostas do banco retornem pelo firewall. Isso faz o banco registrar o endereço do firewall como origem, em vez do IP original do cliente.

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
