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

As regras de INVALID, loopback, ESTABLISHED/RELATED em INPUT e a política OUTPUT ACCEPT são regras de higiene de estado sem teste dedicado. O traceroute é evidência indireta: o salto 1 mostra o firewall; os asteriscos são compatíveis com o descarte, mas não identificam a regra.

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
| Firewall | Qualquer destino | Qualquer protocolo | ACCEPT pela política OUTPUT | O tráfego originado no firewall não é o alvo do controle; o foco do projeto é o tráfego entre redes na chain FORWARD. |

A política de OUTPUT é ACCEPT. Portanto, o firewall não restringe por padrão os pacotes gerados por ele próprio.

# 4. Metodologia de Testes e Validação

## Preparação do ambiente

1. Clone o repositório usando a URL fornecida ao avaliador e entre na pasta clonada:

   ```sh
   git clone https://github.com/Tiago070/firewall-barbearia firewall-barbearia
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
| Negativo | `docker compose exec cliente nmap -Pn -p 8080 172.20.0.10` | A porta 8080 aparece como filtrada, pois não há regra que permita esse fluxo e a política de FORWARD é DROP. |
| Negativo | `docker compose exec cliente ping -c 2 172.16.0.254` | Não há resposta ao ping do endereço LAN do firewall, pois o pacote é destinado ao próprio firewall e INPUT tem política DROP. |
| Diagnóstico | `docker compose exec cliente traceroute -m 5 -w 1 dmz-web` | O primeiro salto esperado é `172.16.0.254`; não se espera resposta dos saltos seguintes até a aplicação web. |

O ping ao próprio firewall falha porque esse tráfego termina nele e passa pela chain INPUT, cuja política padrão é DROP. Isso é diferente do ping ao dmz-web, encaminhado pela chain FORWARD, para o qual há uma regra ICMP explícita. No traceroute até o dmz-web, o primeiro salto identifica o firewall; os probes seguintes não obtêm resposta porque o firewall descarta os probes.

Teste de isolamento: remova a rota do cliente para a DMZ com `docker compose exec -T cliente ip route del 172.20.0.0/24` e execute `docker compose exec -T cliente sh -c curl -sS -I --connect-timeout 3 http://dmz-web; echo "exit=$?"`. O resultado observado no log foi `curl: (28) Connection timed out after 3000 milliseconds` com `exit=28`. A falha ocorre apenas após remover a rota e o serviço volta a responder quando a rota é restaurada, o que comprova que o firewall é o único caminho entre a LAN e a DMZ.

Para conferir a política carregada e os contadores:

```sh
docker compose exec firewall iptables -L FORWARD -n -v
```

Anote os contadores antes e depois de executar os testes negativos. O incremento no contador da regra DROP para TCP/5432 comprova que o pacote destinado ao banco foi descartado por essa regra. Para fluxos não correspondentes a regras específicas, confira também o contador da política DROP de FORWARD. Os contadores são cumulativos desde a última inicialização ou zeragem das regras.

## Comparação das evidências antes e depois

Os valores desta tabela foram extraídos dos arquivos `docs/evidencias/antes-das-regras.txt` e `docs/evidencias/depois-das-regras.txt`.

| Teste | Comando | Antes das regras | Depois das regras | Regra responsável |
|---|---|---|---|---|
| HTTP do cliente para o dmz-web | `docker compose exec -T cliente curl -sS --connect-timeout 3 -o /dev/null -w HTTP %{http_code}\n http://dmz-web` | `HTTP 200` | `HTTP 200` | não medido |
| Ping do cliente para o dmz-web | `docker compose exec -T cliente ping -c 2 -W 2 dmz-web` | `2 packets transmitted, 2 packets received, 0% packet loss` | `2 packets transmitted, 2 packets received, 0% packet loss` | não medido |
| Porta 80 e 8080 do dmz-web | `docker compose exec -T cliente nmap -Pn -p 80,8080 --max-retries 1 172.20.0.10` | `80/tcp open http` e `8080/tcp closed http-proxy` | `80/tcp open http` e `8080/tcp filtered http-proxy` | Política DROP de FORWARD: incremento de 2 pacotes e 88 bytes |
| Porta 5432 do banco | `docker compose exec -T cliente nmap -Pn -p 5432 --max-retries 1 172.20.0.20` | `5432/tcp open postgresql` | `5432/tcp filtered postgresql` | Regra DROP TCP/5432: incremento de 2 pacotes e 88 bytes |
| Ping do cliente para o firewall | `docker compose exec -T cliente ping -c 2 -W 2 172.16.0.254` | `2 packets transmitted, 2 packets received, 0% packet loss` | `2 packets transmitted, 0 packets received, 100% packet loss` | Política DROP de INPUT: incremento de 2 pacotes e 168 bytes |
| Traceroute do cliente para o dmz-web | `docker compose exec -T cliente traceroute -m 3 -w 1 dmz-web` | `1  firewall-barbearia-firewall-1.barbearia-lan (172.16.0.254) ... 2  dmz-web (172.20.0.10)` | `1  firewall-barbearia-firewall-1.barbearia-lan (172.16.0.254) ... 2  * * *` | não medido |
| Wget do dmz-web para o cliente | `docker compose exec -T dmz-web wget -T 3 -q -O- http://172.16.0.10:8080` | `ok` | `wget: download timed out` | Regra DROP de novas conexões DMZ para LAN: incremento de 3 pacotes e 180 bytes |
| Curl sem rota do cliente para a DMZ | `docker compose exec -T cliente sh -c curl -sS -I --connect-timeout 3 http://dmz-web; echo "exit=$?"` | `curl: (28) Connection timed out after 3000 milliseconds` e `exit=28` | `curl: (28) Connection timed out after 3000 milliseconds` e `exit=28` | não medido |

## Referências

- SCARFONE, K.; HOFFMAN, P. Guidelines on firewalls and firewall policy. Gaithersburg: National Institute of Standards and Technology, 2009. Disponível em: https://csrc.nist.gov/publications/detail/sp/800-41/rev-1/final. Acesso em: 19 out. 2026.
- BRASIL. Lei nº 13.709, de 14 de agosto de 2018. Lei Geral de Proteção de Dados Pessoais (LGPD). Brasília, DF: Presidência da República, 2018. Disponível em: https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2018/lei/L13709.htm. Acesso em: 19 out. 2026.
- NETFILTER. Netfilter and iptables project documentation. Disponível em: https://www.netfilter.org/documentation/. Acesso em: 19 out. 2026.

A política deny-by-default foi recomendada por Scarfone e Hoffman (2009) como prática de firewall com regras explícitas e bloqueio por padrão. Os dados pessoais fictícios deste ambiente estão protegidos pela Lei Geral de Proteção de Dados Pessoais, que exige medidas adequadas de segurança e minimização de dados (BRASIL, 2018). A arquitetura do laboratório segue a organização do Netfilter, cujos hooks e mecanismos de filtragem são documentados no projeto oficial (NETFILTER, s.d.).
