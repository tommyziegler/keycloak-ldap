#!/bin/sh
#
# start/stop script for keycloak via Docker
# 2017-12-09
#

set -e

#
# configuration
#

CUSTOMER=opitzconsulting
CONTAINER_NAME=oc_keycloak

DOCKER_EXEC="docker exec -it ${CONTAINER_NAME}"


KEYCLOAK_AUTH_URL=http://localhost:8080/auth


#
# usage
#

print_usage() {
    cat << EOF
Usage: ${SCRIPT} (start|stop|create_ldap_userfederation)
EOF
}

#
# functions
#


# start keycloak server
start() {
	KEYCLOAK_PASS=admin
	LDAPADMIN_PASS=password

	echo "Keycloak Admin Password: $KEYCLOAK_PASS"
	# echo "LDAP Password: $LDAPADMIN_PASS"


	# ## LDAP Server
	docker run -e LDAP_DOMAIN=example.com -e LDAP_ORGANIZATION=${CUSTOMER} -e LDAP_ROOTPASS=${LDAPADMIN_PASS} --name ldap -d -p 389:389 nickstenning/slapd
	sleep 2
	# Import Sample into LDAP Server
	ldapadd -v -h localhost:389 -c -x -D cn=admin,dc=example,dc=com -w ${LDAPADMIN_PASS} -f ldap_sample.ldif

	## Keycloak Server
	# docker run -d --name=${CONTAINER_NAME} -e KEYCLOAK_USER=admin -e KEYCLOAK_PASSWORD=${KEYCLOAK_PASS} -p 8081:8080 jboss/keycloak
	docker run -d --name=${CONTAINER_NAME} -e KEYCLOAK_USER=admin -e KEYCLOAK_PASSWORD=${KEYCLOAK_PASS} -p 8080:8080 --link ldap:ldap jboss/keycloak
	sleep 7

	${DOCKER_EXEC} /opt/jboss/keycloak/bin/kcadm.sh config credentials --realm master --server ${KEYCLOAK_AUTH_URL} --user admin --password ${KEYCLOAK_PASS}

	# Create Keycloak Realm
	${DOCKER_EXEC} /opt/jboss/keycloak/bin/kcadm.sh create realms -s realm=${CUSTOMER} -s enabled=true -o
	# LDAP User Storage Provider
	${DOCKER_EXEC} /opt/jboss/keycloak/bin/kcadm.sh create components -r ${CUSTOMER} \
                    -s id=ldap-userstorageprovider-01 \
                    -s 'name='${CUSTOMER}' LDAP' \
                    -s providerId=ldap \
                    -s providerType=org.keycloak.storage.UserStorageProvider \
                    -s 'config.priority=["1"]' \
                    -s 'config.fullSyncPeriod=["-1"]' \
                    -s 'config.changedSyncPeriod=["-1"]' \
                    -s 'config.cachePolicy=["DEFAULT"]' \
                    -s config.evictionDay=[] \
                    -s config.evictionHour=[] \
                    -s config.evictionMinute=[] \
                    -s config.maxLifespan=[] \
                    -s 'config.batchSizeForSync=["500"]' \
                    -s 'config.editMode=["READ_ONLY"]' \
                    -s 'config.syncRegistrations=["false"]' \
                    -s 'config.vendor=["Other"]' \
                    -s 'config.usernameLDAPAttribute=["uid"]' \
                    -s 'config.rdnLDAPAttribute=["uid"]' \
                    -s 'config.uuidLDAPAttribute=["entryUUID"]' \
                    -s 'config.userObjectClasses=["inetOrgPerson, organizationalPerson"]' \
                    -s 'config.connectionUrl=["ldap://ldap:389"]' \
                    -s 'config.usersDn=["ou=users,dc=example,dc=com"]' \
                    -s 'config.authType=["simple"]' \
                    -s 'config.bindDn=["cn=admin,dc=example,dc=com"]' \
                    -s 'config.bindCredential=["'${LDAPADMIN_PASS}'"]' \
                    -s 'config.customUserSearchFilter=[""]' \
                    -s 'config.searchScope=["1"]' \
                    -s 'config.useTruststoreSpi=["ldapsOnly"]' \
                    -s 'config.connectionPooling=["true"]' \
                    -s 'config.pagination=["false"]'

    ${DOCKER_EXEC} /opt/jboss/keycloak/bin/kcadm.sh create components -r ${CUSTOMER} \
                    -s name=role-ldap-mapper \
                    -s providerId=role-ldap-mapper \
                    -s providerType=org.keycloak.storage.ldap.mappers.LDAPStorageMapper \
                    -s parentId=ldap-userstorageprovider-01 \
                    -s 'config."roles.dn"=["ou=groups,dc=example,dc=com"]' \
                    -s 'config."role.name.ldap.attribute"=["cn"]' \
                    -s 'config."role.object.classes"=["groupOfNames"]' \
                    -s 'config."membership.ldap.attribute"=["member"]' \
                    -s 'config."membership.attribute.type"=["DN"]' \
                    -s 'config."membership.user.ldap.attribute"=["member"]' \
                    -s 'config."user.roles.retrieve.strategy"=["LOAD_ROLES_BY_MEMBER_ATTRIBUTE"]' \
                    -s 'config."mode"=["READ_ONLY"]' \
                    -s 'config."roles.ldap.filter"=[]' \
                    -s 'config."client.id"=[]' \
                    -s 'config."use.realm.roles.mapping"=["true"]'

	sleep 1
    # Sync LDAP Users into Keycloak database
    ${DOCKER_EXEC} /opt/jboss/keycloak/bin/kcadm.sh create user-storage/ldap-userstorageprovider-01/sync?action=triggerFullSync -r ${CUSTOMER}

	sleep 1
	TEST_CLIENT_PORT=8888
    # Create Test-Client App
    ${DOCKER_EXEC} /opt/jboss/keycloak/bin/kcadm.sh create clients -r ${CUSTOMER} \
                    -s 'enabled=true' \
                    -s 'clientId=test-client' \
                    -s 'rootUrl=http://localhost:'${TEST_CLIENT_PORT}'/*' \
                    -s 'redirectUris=["http://localhost:'${TEST_CLIENT_PORT}'/*"]' \
                    -s 'publicClient=true'

    cd demo-keycloak
    mvn clean install spring-boot:run -DskipTests -Dserver.port=${TEST_CLIENT_PORT}
}


# stop keycloak server
stop() {
	docker stop ${CONTAINER_NAME}
	docker rm ${CONTAINER_NAME}
	docker stop ldap
	docker rm ldap
}

#
# main
#

if [[ ${#} -lt 1 ]]; then
  print_usage
  exit 2
fi

ACTION=${1}

case ${ACTION} in
  start )
    start
    ;;
  stop )
    stop
    ;;
  * )
    print_usage
    exit 2
    ;;
esac
