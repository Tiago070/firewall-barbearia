# 1. Definição do Case

A TIBarber é uma barbearia fictícia com 20 funcionários e 5 unidades. O sistema de agendamento funciona em um servidor local. A escolha do servidor local é justificada pela integração com o caixa, pela possibilidade de funcionamento sem depender da internet e pela ausência de mensalidade de SaaS.

O serviço depende de uma aplicação web de agendamento e de um banco PostgreSQL. O banco contém nome, telefone e histórico de clientes, que são dados pessoais sujeitos à Lei Geral de Proteção de Dados Pessoais, Lei nº 13.709/2018. Os registros utilizados na simulação são fictícios.

# 2. Diagnóstico

## Cenário atual

No cenário hipotético inicial, o Wi-Fi de clientes, o computador do caixa e o servidor estão conectados ao mesmo roteador, sem segmentação. Qualquer dispositivo da rede pode acessar o banco. Também não há controle do tráfego que entra ou sai nem registro das tentativas bloqueadas. Essa configuração amplia a exposição dos dados pessoais e dificulta identificar tentativas de acesso não autorizado.

## Proposta e arquitetura

A proposta separa a LAN, destinada à recepção e ao caixa, da DMZ, que contém a aplicação web e o banco. O firewall Linux é o caminho entre as duas redes e aplica uma política deny-by-default: as chains INPUT e FORWARD têm política DROP, e somente os fluxos explicitamente permitidos são encaminhados. A chain OUTPUT permanece em ACCEPT.

No Netfilter, os hooks PREROUTING e POSTROUTING atuam antes e depois da decisão de roteamento, respectivamente. Após PREROUTING, um pacote destinado ao próprio firewall segue para INPUT; um pacote encaminhado entre redes segue para FORWARD. OUTPUT trata pacotes gerados pelo próprio firewall. As tabelas organizam as regras por finalidade: neste projeto, as regras de filtragem estão na tabela filter; as tabelas nat e mangle são limpas na inicialização, sem receber regras novas. O conntrack acompanha o estado das conexões: as regras usam `-m conntrack --ctstate` para descartar pacotes INVALID e aceitar tráfego ESTABLISHED,RELATED. Como o tráfego entre LAN e DMZ é roteado, suas permissões e bloqueios são aplicados em FORWARD, não em INPUT ou OUTPUT.

## Decisões e limitações

O banco permanece dentro da DMZ, conforme o enunciado. O fluxo da aplicação web para o banco ocorre dentro da mesma rede DMZ e, por isso, não atravessa o firewall nem é filtrado pelas regras de FORWARD deste projeto. O container do banco não recebe NET_ADMIN e não tem rota configurada para a LAN. O cliente e o dmz-web recebem NET_ADMIN somente para ajustar suas rotas estáticas, como artefato da simulação; o firewall recebe NET_ADMIN para configurar as regras e encaminhar pacotes.

O filtro de pacotes não inspeciona a camada 7. HTTPS na porta 443 não está implementado. A concessão de NET_ADMIN ao dmz-web amplia a superfície de ataque caso esse servidor seja comprometido. Todos os dados presentes no ambiente são fictícios.

# 3. Matriz de Regras de Segurança

As linhas abaixo refletem as regras e as políticas configuradas em `firewall/entrypoint.sh`. As duas últimas linhas representam políticas padrão da chain, e não regras adicionadas individualmente. Todo tráfego que não corresponde a uma regra ACCEPT ou DROP explícita é tratado pela política da chain.

| Origem | Destino | Porta/Protocolo | Ação | Justificativa do Negócio |
|---|---|---|---|---|
| Interface de loopback (`lo`) | Próprio firewall | Todos | ACCEPT em INPUT | Permite a comunicação local do sistema. |
| Qualquer origem | Próprio firewall | Pacotes com estado INVALID | DROP em INPUT | Descarta pacotes inválidos destinados ao firewall. |
| Qualquer origem | Qualquer destino encaminhado | Pacotes com estado INVALID | DROP em FORWARD | Descarta pacotes inválidos que tentem atravessar o firewall. |
| LAN (`172.16.0.0/24`) | Banco (`172.20.0.20`) | TCP, destino 5432 | DROP em FORWARD | Impede que clientes da LAN acessem diretamente o PostgreSQL. |
| Conexões já estabelecidas ou relacionadas | Próprio firewall | Qualquer protocolo | ACCEPT em INPUT | Permite o tráfego de resposta de conexões aceitas com o firewall. |
| Conexões já estabelecidas ou relacionadas | Entre redes | Qualquer protocolo | ACCEPT em FORWARD | Permite as respostas de conexões previamente autorizadas. |
| LAN (`172.16.0.0/24`) | Aplicação web (`172.20.0.10`) | TCP, destino 80, estado NEW | ACCEPT em FORWARD | Permite o acesso ao sistema de agendamento web. |
| DMZ (`172.20.0.0/24`) | LAN (`172.16.0.0/24`) | Novas conexões, qualquer protocolo | DROP em FORWARD | Evita que a DMZ inicie conexões novas em direção à rede interna. |
| LAN (`172.16.0.0/24`) | Aplicação web (`172.20.0.10`) | ICMP echo-request | ACCEPT em FORWARD | Permite verificar a conectividade com o servidor web. |
| Qualquer origem | Próprio firewall | Tráfego não aceito por regra anterior | DROP pela política INPUT | Mantém bloqueado por padrão o tráfego destinado ao firewall, inclusive ping para seus endereços. |
| Qualquer origem | Qualquer destino encaminhado | Tráfego não aceito por regra anterior | DROP pela política FORWARD | Bloqueia, entre outros fluxos, o acesso da LAN à DMZ em portas não liberadas explicitamente. |

A política de OUTPUT é ACCEPT. Portanto, o firewall não restringe por padrão os pacotes gerados por ele próprio.

# 4. Metodologia de Testes e Validação

## Preparação do ambiente

1. Clone o repositório usando a URL fornecida ao avaliador e entre na pasta clonada:

   ```sh
   git clone <https://github.com/Tiago070/firewall-barbearia> firewall-barbearia
   cd firewall-barbearia
   ```


2. Crie o arquivo de configuração local a partir do exemplo:

   ```sh
   cp .env.example .env
   ```

3. Construa as imagens e inicie os containers:

   ```sh
   docker compose up -d --build
   ```

4. Confira o estado dos serviços:

   ```sh
   docker compose ps
   ```

   Resultado esperado: os serviços firewall, cliente, dmz-web e dmz-db aparecem em execução.

## Testes positivos e negativos

Execute os comandos a partir da pasta do projeto.

| Tipo | Comando | Resultado esperado |
|---|---|---|
| Positivo | `docker compose exec cliente curl -fsS http://dmz-web/` | A solicitação HTTP termina com código de saída zero e retorna o conteúdo servido pelo Nginx. |
| Positivo | `docker compose exec cliente ping -c 2 dmz-web` | Há respostas ICMP da aplicação web, pois a regra permite echo-request da LAN para esse host. |
| Negativo | `docker compose exec cliente nmap -Pn -p 5432 172.20.0.20` | A porta 5432 aparece como filtrada, pois o acesso TCP da LAN ao banco é descartado. |
| Negativo | `docker compose exec cliente nmap -Pn -p 22 172.20.0.10` | A porta 22 aparece como filtrada, pois não há regra que permita esse fluxo e a política de FORWARD é DROP. |
| Negativo | `docker compose exec cliente ping -c 2 172.16.0.254` | Não há resposta ao ping do endereço LAN do firewall, pois o pacote é destinado ao próprio firewall e INPUT tem política DROP. |
| Diagnóstico | `docker compose exec cliente traceroute -m 5 -w 1 dmz-db` | O primeiro salto esperado é `172.16.0.254`; não se espera resposta dos saltos seguintes até o banco. |

O ping ao próprio firewall falha porque esse tráfego termina nele e passa pela chain INPUT, cuja política padrão é DROP. Isso é diferente do ping ao dmz-web, encaminhado pela chain FORWARD, para o qual há uma regra ICMP explícita. No traceroute até o banco, o primeiro salto identifica o firewall; os probes seguintes não obtêm resposta porque o acesso da LAN ao banco é bloqueado e o banco não tem rota configurada para a LAN.

Para conferir a política carregada e os contadores:

```sh
docker compose exec firewall iptables -L FORWARD -n -v
```

Anote os contadores antes e depois de executar os testes negativos. O incremento no contador da regra DROP para TCP/5432 comprova que o pacote destinado ao banco foi descartado por essa regra. Para fluxos não correspondentes a regras específicas, confira também o contador da política DROP de FORWARD. Os contadores são cumulativos desde a última inicialização ou zeragem das regras.

## Comparação das evidências antes e depois

A pasta `docs/evidencias` não contém arquivos com resultados dos testes; contém apenas o marcador `.gitkeep`. Assim, não há valores medidos que possam ser atribuídos a uma execução antes ou depois das regras. A tabela registra essa ausência sem substituir medições por resultados esperados.

| Teste/indicador | Antes das regras, valor em `docs/evidencias` | Depois das regras, valor em `docs/evidencias` |
|---|---|---|
| Acesso HTTP do cliente à aplicação web | Não registrado | Não registrado |
| Acesso TCP do cliente ao PostgreSQL na porta 5432 | Não registrado | Não registrado |
| Acesso do cliente à porta 22 do dmz-web | Não registrado | Não registrado |
| Ping do cliente ao firewall | Não registrado | Não registrado |
| Traceroute do cliente até o banco | Não registrado | Não registrado |
| Contadores da chain FORWARD | Não registrado | Não registrado |

Os resultados esperados para a configuração atual estão descritos na tabela de testes acima; para preencher esta comparação com resultados observados, execute os testes e salve as saídas correspondentes em `docs/evidencias`.

## Referências

- NIST SP 800-41 Rev. 1 (Scarfone e Hoffman, 2009).
- Lei nº 13.709/2018.
- Documentação do Netfilter em netfilter.org.
