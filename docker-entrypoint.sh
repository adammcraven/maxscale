#!/bin/bash

# Exit if any subcommand or pipeline returns a non-zero status.
set -ex

validate_variables() {
	
	if [ ! $DB_SERVER_ADDRESSES ]; then
	  echo "==> ERROR: DB_SERVER_ADDRESSES was not supplied"
	  exit -1
	fi
	
	if [ ! $DB_SERVER_PORTS ]; then
	  echo "==> ERROR: DB_SERVER_PORTS was not supplied"
	  exit -1
	fi	
	
	if [ ! $MAXSCALE_USER ]; then
	  echo "==> ERROR: MAXSCALE_USER was not supplied"
	  exit -1
	fi
	
	if [ ! $MAXSCALE_PASSWORD ]; then
	  echo "==> ERROR: MAXSCALE_PASSWORD was not supplied"
	  exit -1
	fi
	
	if [ ! $MONITOR_USER ]; then
	  echo "==> ERROR: MONITOR_USER was not supplied"
	  exit -1
	fi
	
	if [ ! $MONITOR_PASSWORD ]; then
	  echo "==> ERROR: MONITOR_PASSWORD was not supplied"
	  exit -1
	fi
	
}

function joinArrayToString { local IFS="$1"; shift; echo "$*"; }

create_config_file() {

    dbServers=()
	dbServerPorts=()

	# Split comma separated list of database server addresses
	IFS=',' read -r -a dbServerAddresses <<< "$DB_SERVER_ADDRESSES"
    IFS=',' read -r -a dbServerPorts <<< "$DB_SERVER_PORTS"

	for index in "${!dbServerAddresses[@]}"
	do
	  position = ${index+1}
	  
      ipAddress = ${dbServerAddresses[index]} | sed 's/[[:space:]]//g'
      #addressHostName = "address${position}"
      # echo $address1  address1 >> /etc/hosts
      #echo $ipAddress  $addressHostName >> /etc/hosts

	  dbServers+=("server${position}")	  
    done
	
	commaSeparatedDbServers=joinArrayToString , "${dbServers[@]}"
	
	# Reference:
	# https://mariadb.com/kb/en/mariadb-enterprise/mariadb-maxscale/maxscale-configuration-usage-scenarios/
	
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
	router=readconnroute
	router_options=master,slave
	***TODO servers=$commaSeparatedDbServers
	
	[Splitter Service]
	type=service
	router=readwritesplit
	***TODO servers=$commaSeparatedDbServers
	user=$MAXSCALE_USER
	passwd=$MAXSCALE_PASSWORD
	
	[Splitter Listener]
	type=listener
	service=Splitter Service
	protocol=MySQLClient
	port=3306
	socket=/tmp/ClusterMaster
	
	
EOM
	) >> $maxscaleConf


#ssl=required
#ssl_cert=/home/markus/certs/server-cert.pem
#ssl_key=/home/markus/certs/server-key.pem
#ssl_ca_cert=/home/markus/certs/ca.pem
#ssl_version=TLSv12	


	for index in "${!dbServerAddresses[@]}"
	do
	  position = ${index+1}
      ipAddress = ${dbServerAddresses[index]} | sed 's/[[:space:]]//g'
	  port = ${dbServerPorts[index]} | sed 's/[[:space:]]//g'
	
	  ( cat <<EOM
		[server$position]
		type=server
		address=$ipAddress
		port=$port
		# lowest index server, if available, becomes Master
		wsrep_local_index=$position
		protocol=MySQLBackend
		monitoruser=$MONITOR_USER
		monitorpw=$MONITOR_PASSWORD
EOM
	  ) >> $maxscaleConf
    done



	
	( cat <<EOM
	[Galera Monitor]
	type=monitor
	module=galeramon
	servers=$commaSeparatedDbServers
	user=$MONITOR_USER
	passwd=$MONITOR_PASSWORD
	monitor_interval=8000
	backend_connect_timeout=3
	backend_read_timeout=1
	backend_write_timeout=2
	# galeramon specific options
	disable_master_failback=0
	available_when_donor=0
	# 0 = set servers to operate as master or slave 
	disable_master_role_setting=0
	
	
	
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
