# keycloak-ldap
Provision a Keycloak Server with LDAP Connection

## Prerequirements
* Docker Installation
* Java + Maven

## Start Server
```
chmod +x bootstrap.sh
./bootstrap.sh start
```

```
./bootstrap.sh stop && ./bootstrap.sh start
```

# Additional sources
https://jaxenter.de/authentifizierung-autorisierung-angular-56732
https://connect2id.com/learn/openid-connect

### Beispiel aus Jaxenter Artikel (nicht Lauffähig :/)
https://github.com/hpgrahsl/FlightsWebAPI
https://github.com/manfredsteyer/angular-oauth2-oidc-sample

### Original Beispiel vom Angular OAuth2 Adapter für Keycloak
https://github.com/manfredsteyer/angular-oauth2-oidc

### Keycloak Documentation
http://www.keycloak.org/documentation.html

### Keycloak Examples
https://github.com/keycloak/keycloak/tree/master/examples

### OpenID Connect in a Nutshell
http://www.simpleorientedarchitecture.com/openid-connect-in-a-nutshell/
