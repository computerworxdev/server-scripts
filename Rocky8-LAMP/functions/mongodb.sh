#!/bin/sh

. messages.sh

install_mongodb() {
OS_VERSION=$(rpm -E %rhel)
MONGO_VERSION="6.0"
MONGO_REPO_BASEURL="https://repo.mongodb.org/yum/redhat/$OS_VERSION/mongodb-org/${MONGO_VERSION}/x86_64/"
MONGO_GPGKEY="https://pgp.mongodb.com/server-${MONGO_VERSION}.asc"

MONGOCONFIG=$(cat <<EOF
[mongodb-org-${MONGO_VERSION}]
name=MongoDB Repository
baseurl=${MONGO_REPO_BASEURL}
gpgcheck=1
enabled=1
gpgkey=${MONGO_GPGKEY}
EOF
)

    echo "$MONGOCONFIG" > /etc/yum.repos.d/mongodb-org-${MONGO_VERSION}.repo
    dnf makecache
    dnf install -y mongodb-org mongodb-shell
    if [ ! -f "/etc/mongod.conf.bak" ]; then
        cp /etc/mongod.conf /etc/mongod.conf.bak
    fi
    sed -i '/^security:/a \ authorization: enabled' /etc/mongod.conf
    systemctl enable mongod
    systemctl start mongod
    sleep 30

mongosh <<EOF
disableTelemetry()
EOF
}

create_mongodb_root_user() {
    if [ "$#" -ne 2 ]; then
        alert "Incorrect number of parameters"
        echo "Provide: username and password"
        return 1
    fi
MONGOUSERCONFIG=$(cat <<EOF
use admin
db.createUser({
  user: "$1",
  pwd: "$2",
  roles: [{ role: "root", db: "admin" }]
})
EOF
)
    echo "$MONGOUSERCONFIG" | mongosh
}



