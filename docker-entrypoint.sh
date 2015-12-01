#!/bin/bash

# Exit if any subcommand or pipeline returns a non-zero status.
set -ex

validate_variables() {
	
	if [ ! $DB_SERVER_ADDRESSES ]; then
	echo "==> ERROR: DB_SERVER_ADDRESSES was not supplied"
	exit -1
	fi
	
	if [ ! $GALERAMON_USER ]; then
	echo "==> ERROR: GALERAMON_USER was not supplied"
	exit -1
	fi
	
	if [ ! $GALERAMON_PASSWORD ]; then
	echo "==> ERROR: GALERAMON_PASSWORD was not supplied"
	exit -1
	fi
}

function joinArrayToString { local IFS="$1"; shift; echo "$*"; }

create_config_file() {

    dbServers=()

	# Split comma separated list of database server addresses
	IFS=',' read -r -a dbServerAddresses <<< "$DB_SERVER_ADDRESSES"
	for index in "${!dbServerAddresses[@]}"
	do
	  position = ${index+1}
	  
      ipAddress = ${dbServerAddresses[index]} | sed 's/[[:space:]]//g'
      addressHostName = "address${position}"
      # echo $address1  address1 >> /etc/hosts
      echo $ipAddress  $addressHostName >> /etc/hosts

	  dbServers+=("dbserv${position}")	  
    done
	
	commaSeparatedDbServers=joinArrayToString , "${dbServers[@]}"
	
	echo "==> Creating maxscale config file"
	maxscaleConf="/etc/maxscale.d/maxscale.cnf"
	
	( cat <<EOM
	[maxscale]
	threads=2
	log_messages=1
	log_trace=0
	log_debug=0
	logdir=/tmp/
	
	[Splitter Service]
	type=service
	router=readwritesplit
	servers=$commaSeparatedDbServers
	
	[Splitter Service]
	type=service
	router=readwritesplit
	servers=$commaSeparatedDbServers
	user=$GALERAMON_USER
	passwd=$GALERAMON_PASSWORD
	
	[Splitter Listener]
	type=listener
	service=Splitter Service
	protocol=MySQLClient
	port=3306
	socket=/tmp/ClusterMaster
EOM
	) >> $maxscaleConf



TODO	
	# Do a loop here instead
	( cat <<EOM
	[dbserv1]
	type=server
	address=address1
	port=3306
	protocol=MySQLBackend
	
	[dbserv2]
	type=server
	address=address2
	port=3306
	protocol=MySQLBackend
	
	[dbserv3]
	type=server
	address=address3
	port=3306
	protocol=MySQLBackend
	
EOM
	) >> $maxscaleConf
	
	( cat <<EOM
	[Galera Monitor]
	type=monitor
	module=galeramon
	servers=$commaSeparatedDbServers
	user=$GALERAMON_USER
	passwd=$GALERAMON_PASSWORD
	
	[CLI]
	type=service
	router=cli
	
	[CLI Listener]
	type=listener
	service=CLI
	protocol=maxscaled
	address=localhost
	port=6604
EOM
	) >> $maxscaleConf
}

run() {
	# Run maxscale
	echo "==> Starting Maxscale"
	/usr/bin/maxscale -d
	echo "==> Maxscale exited"
}


###########################################
################## Start ##################
###########################################
echo "==> Starting docker-entrypoint.sh"
validate_variables
create_config_file
run
