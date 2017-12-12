#!/bin/sh
#
# start/stop script for keycloak via Docker
# 2017-12-09
#

set -e

#
# configuration
#

CUSTOMER=OpitzConsulting
KC_REALM_NAME=opitzconsulting
KC_CONTAINER_NAME=oc_keycloak

DOCKER_EXEC="docker exec -it ${KC_CONTAINER_NAME}"


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
    echo "LDAP Password: $LDAPADMIN_PASS"


    # ## LDAP Server
    docker run -e LDAP_DOMAIN=example.com -e LDAP_ORGANIZATION=${CUSTOMER} -e LDAP_ROOTPASS=${LDAPADMIN_PASS} --name ldap -d -p 389:389 nickstenning/slapd
    sleep 2
    # Import Sample into LDAP Server
    ldapadd -v -h localhost:389 -c -x -D cn=admin,dc=example,dc=com -w ${LDAPADMIN_PASS} -f ldap_sample.ldif

    ## Keycloak Server
    docker run -d --name=${KC_CONTAINER_NAME} -e KEYCLOAK_USER=admin -e KEYCLOAK_PASSWORD=${KEYCLOAK_PASS} -p 8080:8080 --link ldap:ldap jboss/keycloak
    sleep 7

    ${DOCKER_EXEC} /opt/jboss/keycloak/bin/kcadm.sh config credentials --realm master --server ${KEYCLOAK_AUTH_URL} --user admin --password ${KEYCLOAK_PASS}

    # Create Keycloak Realm
    ${DOCKER_EXEC} /opt/jboss/keycloak/bin/kcadm.sh create realms -s realm=${KC_REALM_NAME} -s enabled=true -o
    # LDAP User Storage Provider
    ${DOCKER_EXEC} /opt/jboss/keycloak/bin/kcadm.sh create components -r ${KC_REALM_NAME} \
                    -s id=ldap-userstorageprovider-01 \
                    -s 'name="'${CUSTOMER}' LDAP"' \
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

    ${DOCKER_EXEC} /opt/jboss/keycloak/bin/kcadm.sh create components -r ${KC_REALM_NAME} \
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
    ${DOCKER_EXEC} /opt/jboss/keycloak/bin/kcadm.sh create user-storage/ldap-userstorageprovider-01/sync?action=triggerFullSync -r ${KC_REALM_NAME}

    sleep 1
    TEST_CLIENT_PORT=8888
    TEST_CLIENT_ID=keycloak-spring-demo
    # Create Test-Client App
    ${DOCKER_EXEC} /opt/jboss/keycloak/bin/kcadm.sh create clients -r ${KC_REALM_NAME} \
                    -s 'enabled=true' \
                    -s 'clientId='${TEST_CLIENT_ID} \
                    -s 'rootUrl=http://localhost:'${TEST_CLIENT_PORT}'/*' \
                    -s 'redirectUris=["http://localhost:'${TEST_CLIENT_PORT}'/*"]' \
                    -s 'publicClient=true'

    if [ ! -d keycloak-spring-demo ] ; then
        git clone https://github.com/tommyziegler/keycloak-spring-demo.git
        cd keycloak-spring-demo
    else
        cd keycloak-spring-demo
        git up
    fi



    mvn clean install spring-boot:run \
                    -DskipTests \
            -Dserver.port=${TEST_CLIENT_PORT} \
            -Dkeycloak.realm=${KC_REALM_NAME} \
            -Dkeycloak.resource=${TEST_CLIENT_ID}
    # Via Docker (first Test DNS Route to different Docker Names \ Images)
    #docker run -it --rm --name keycloak-spring-demo -v "$PWD":/usr/src/mymaven -w /usr/src/mymaven maven:3-jdk-8 mvn install spring-boot:run -DskipTests -Dserver.port=${TEST_CLIENT_PORT} -Dkeycloak.realm=${KC_REALM_NAME} -Dkeycloak.resource=${TEST_CLIENT_ID}
}


# stop keycloak server
stop() {
    docker stop ${KC_CONTAINER_NAME}
    docker rm ${KC_CONTAINER_NAME}
    docker stop ldap
    docker rm ldap
    #docker stop keycloak-spring-demo
    #docker rm keycloak-spring-demo
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
