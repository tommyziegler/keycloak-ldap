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
 - https://jaxenter.de/authentifizierung-autorisierung-angular-56732
 - https://connect2id.com/learn/openid-connect

### Beispiel aus Jaxenter Artikel (nicht Lauffähig :/)
 - https://github.com/hpgrahsl/FlightsWebAPI
 - https://github.com/manfredsteyer/angular-oauth2-oidc-sample

### Original Beispiel vom Angular OAuth2 Adapter für Keycloak
 - https://github.com/manfredsteyer/angular-oauth2-oidc

### Keycloak Documentation
 - http://www.keycloak.org/documentation.html
#### Admin CLI
 - https://github.com/keycloak/keycloak-documentation/blob/master/server_admin/topics/admin-cli.adoc

### Keycloak Examples
 - https://github.com/keycloak/keycloak/tree/master/examples
#### User Storage Federation (via LDAP)
 - http://www.keycloak.org/docs/latest/server_admin/index.html#_ldap
 - https://access.redhat.com/documentation/en-us/red_hat_single_sign-on/7.1-beta/html/server_administration_guide/user-storage-federation#ldap_mappers

### OpenID Connect in a Nutshell
 - http://www.simpleorientedarchitecture.com/openid-connect-in-a-nutshell/

### More
https://dzone.com/articles/easily-secure-your-spring-boot-applications-with-k
http://slackspace.de/articles/authentication-with-spring-boot-angularjs-and-keycloak/
