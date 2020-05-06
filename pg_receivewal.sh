#!/bin/bash

PG_PROBACKUP_DIRECTORY="/var/lib/pg_probackup"
PG_PROBACKUP_BACKUP_DIRECTORY="${PG_PROBACKUP_DIRECTORY}/backups"
PG_PROBACKUP_WAL_DIRECTORY="${PG_PROBACKUP_DIRECTORY}/wal"
LOG_FILENAME="${PG_PROBACKUP_DIRECTORY}/bin/pg_receivewal.log"
PG_APPLICATION_NAME="pg_probackup"
PG_REPLICATION_HOST=""
PG_REPLICATION_USER=""
PG_REPLICATION_SLOT_NAME="pg_probackup"
PG_RECEIVEWAL_BIN="/usr/pgsql-12/bin/pg_receivewal"

function show_help() {
	echo "Usage: $0 [-h] [--help] [--create-slot] [--drop-slot] [--check-receivewal]"
	echo "Example: $0 --create-slot [slot_name|default] [server_name|all]"
	echo "Example: $0 --drop-slot [slot_name|default] [server_name|all]"
	echo "Example: $0 --check-receivewal [server_name|all]"
}

function log {
	echo "$(date +%Y-%m-%d\ %H:%M:%S): $1" &>> ${LOG_FILENAME}
	echo "$(date +%Y-%m-%d\ %H:%M:%S): $1"
}

function create_slot() {
	SERVER_NAME="$1"
	if ! get_settings "${SERVER_NAME}"; then
		return 1
	fi
	log "INFO: creating replication slot '${PG_REPLICATION_SLOT_NAME}' on the server '${SERVER_NAME}'."
	PG_RECEIVEWAL_BIN_OUTPUT=$(${PG_RECEIVEWAL_BIN} \
		--dbname="dbname=replication host=${PG_REPLICATION_HOST} options=-cdatestyle=iso port=5432 replication=true user=${PG_REPLICATION_USER} application_name=${PG_APPLICATION_NAME}" \
		--verbose \
		--no-loop \
		--no-password \
		--slot=${PG_REPLICATION_SLOT_NAME} \
		--create-slot \
		2>&1
	)
	log "PG_RECEIVEWAL_BIN_OUTPUT=${PG_RECEIVEWAL_BIN_OUTPUT}"
	return 0
}

function drop_slot() {
	SERVER_NAME="$1"
	if ! get_settings "${SERVER_NAME}"; then
		return 1
	fi
	log "INFO: droping replication slot '${PG_REPLICATION_SLOT_NAME}' on the server '${SERVER_NAME}'."
	PG_RECEIVEWAL_BIN_OUTPUT=$(${PG_RECEIVEWAL_BIN} \
		--dbname="dbname=replication host=${PG_REPLICATION_HOST} options=-cdatestyle=iso port=5432 replication=true user=${PG_REPLICATION_USER} application_name=${PG_APPLICATION_NAME}" \
		--verbose \
		--no-loop \
		--no-password \
		--slot=${PG_REPLICATION_SLOT_NAME} \
		--drop-slot \
		2>&1
	)
	log "PG_RECEIVEWAL_BIN_OUTPUT=${PG_RECEIVEWAL_BIN_OUTPUT}"
	return 0
}

function check_receivewal() {
	SERVER_NAME="$1"
	if ! get_settings "${SERVER_NAME}"; then
		return 1
	fi
	if [[ $(ps ax | grep -v grep | grep "${PG_RECEIVEWAL_BIN}" | grep -E " host=${PG_REPLICATION_HOST} .+ application_name=${PG_APPLICATION_NAME} " | wc -l) == "0" ]]; then
		log "INFO: starting '${PG_RECEIVEWAL_BIN}' on the server '${SERVER_NAME}'."
		${PG_RECEIVEWAL_BIN} \
			--dbname="dbname=replication host=${PG_REPLICATION_HOST} options=-cdatestyle=iso port=5432 replication=true user=${PG_REPLICATION_USER} application_name=${PG_APPLICATION_NAME}" \
			--directory=${PG_PROBACKUP_WAL_DIRECTORY}/${SERVER_NAME} \
			--slot=${PG_REPLICATION_SLOT_NAME} \
			--verbose \
			--no-loop \
			--no-password \
			--compress=9 \
			&>/dev/null &
	fi
	return 0
}

function get_settings() {
	SERVER_NAME="$1"
	if ! [[ -d "${PG_PROBACKUP_BACKUP_DIRECTORY}/${SERVER_NAME}" ]]; then
		log "ERROR: server '${SERVER_NAME}' does not exist!"
		return 1
	fi
	if ! [[ -f "${PG_PROBACKUP_BACKUP_DIRECTORY}/${SERVER_NAME}/pg_probackup.conf" ]]; then
		log "ERROR: configuration file '${PG_PROBACKUP_BACKUP_DIRECTORY}/${SERVER_NAME}/pg_probackup.conf' does not exist!"
		return 1
	fi
	PG_REPLICATION_HOST=$(cat "${PG_PROBACKUP_BACKUP_DIRECTORY}/${SERVER_NAME}/pg_probackup.conf" | grep pghost | awk '{print $3}')
	PG_REPLICATION_USER=$(cat "${PG_PROBACKUP_BACKUP_DIRECTORY}/${SERVER_NAME}/pg_probackup.conf" | grep pguser | awk '{print $3}')
	return 0
}

case $# in
	1)
		case $1 in
			--help|-h|*)
				show_help
				;;
		esac
		exit 0
		;;
	2)
		case $1 in
			--check-receivewal)
				SERVER_NAME="$2"
				if [[ "${SERVER_NAME}" == "all" ]]; then
					for SERVER_NAME in $(ls -Ad "${PG_PROBACKUP_BACKUP_DIRECTORY}"/*/ | xargs -n 1 -d '\n' basename); do
						if ! check_receivewal "${SERVER_NAME}"; then
							exit 1
    						fi
					done
				else
					if ! check_receivewal "${SERVER_NAME}"; then
						exit 1
					fi
				fi
				exit 0
				;;
			*)
				show_help
				;;
		esac
		exit 0
		;;
	3)
		case $1 in
			--create-slot)
				if [[ "$2" != "default" ]]; then
					PG_REPLICATION_SLOT_NAME="$2"
				fi
				SERVER_NAME="$3"
				if [[ "${SERVER_NAME}" == "all" ]]; then
					for SERVER_NAME in $(ls -Ad "${PG_PROBACKUP_BACKUP_DIRECTORY}"/*/ | xargs -n 1 -d '\n' basename); do
						if ! create_slot "${SERVER_NAME}"; then
							exit 1
    						fi
					done
				else
					if ! create_slot "${SERVER_NAME}"; then
						exit 1
					fi
				fi
				exit 0
				;;
			--drop-slot)
				if [[ "$2" != "default" ]]; then
					PG_REPLICATION_SLOT_NAME="$2"
				fi
				SERVER_NAME="$3"
				if [[ "${SERVER_NAME}" == "all" ]]; then
					for SERVER_NAME in $(ls -Ad "${PG_PROBACKUP_BACKUP_DIRECTORY}"/*/ | xargs -n 1 -d '\n' basename); do
						if ! drop_slot "${SERVER_NAME}"; then
							exit 1
    						fi
					done
				else
					if ! drop_slot "${SERVER_NAME}"; then
						exit 1
					fi
				fi
				exit 0
				;;
			*)
				show_help
				;;
		esac
		exit 0
		;;
	0|*)
		show_help
		exit 1
		;;
esac
