#!/bin/sh

#
# Display settings on standard out.
#

USER="transmission"

echo "Transmission settings"
echo "====================="
echo
echo "  User:    ${USER}"
echo "  UID:     ${TRANSMISSION_UID:=666}"
echo "  GID:     ${TRANSMISSION_GID:=666}"
echo "  CHMOD:   ${CHMOD:=false}"
echo
echo "  Config:  ${CONFIG:=/etc/transmission/settings.json}"
echo

#
# Change UID / GID of Transmission user.
#

printf "Updating UID / GID if needed... "
[[ $(id -u ${USER}) == ${TRANSMISSION_UID} ]] || usermod  -o -u ${TRANSMISSION_UID} ${USER}
[[ $(id -g ${USER}) == ${TRANSMISSION_GID} ]] || groupmod -o -g ${TRANSMISSION_GID} ${USER}
echo "[DONE]"

#
# Validate files and accesses
#

# Check config file
[[ ! -f /etc/transmission/settings.json ]] && \
        cp /etc/defaults/transmission/settings.json /etc/transmission/settings.json

# If provided, update WebUI user and password
if [ ! -z "${WEBUSER}" ] && [ ! -z "${WEBPASS}" ]; then
    sed -i '/rpc-authentication-required/c\    "rpc-authentication-required": true,' /etc/transmission/settings.json
    sed -i "/rpc-username/c\    \"rpc-username\": \"${WEBUSER}\"," /etc/transmission/settings.json
    sed -i "/rpc-password/c\    \"rpc-password\": \"${WEBPASS}\"," /etc/transmission/settings.json
fi

if [ ! -z "${WHITELIST}" ]; then
    sed -i '/rpc-whitelist-enabled/c\    "rpc-whitelist-enabled": true,' /etc/transmission/settings.json
    sed -i "/\"rpc-whitelist\"/c\    \"rpc-whitelist\": \"${WHITELIST}\"," /etc/transmission/settings.json
fi

if [ ! -z "${HOST_WHITELIST}" ]; then
    sed -i '/rpc-host-whitelist-enabled/c\    "rpc-host-whitelist-enabled": true,' /etc/transmission/settings.json
    sed -i "/\"rpc-host-whitelist\"/c\    \"rpc-host-whitelist\": \"${HOST_WHITELIST}\"," /etc/transmission/settings.json
fi

if [ ! -z "${PEERPORT}" ]; then
    sed -i "/\"peer-port\"/c\    \"peer-port\": ${PEERPORT}," /etc/transmission/settings.json
    sed -i '/peer-port-random-on-start/c\     "peer-port-random-on-start": false,' /etc/transmission/settings.json
fi

#
# Set directory permissions.
#

printf "Set permissions... "
touch ${CONFIG}
chown -R ${USER}:${USER} \
      /etc/transmission \
      /home/transmission \
      > /dev/null 2>&1
[[ "${CHMOD}" == "false" ]] || \
    chown -R ${USER}:${USER} \
          /mnt/transmission/watch \
          /mnt/transmission/torrents \
          /mnt/transmission/downloads \
          > /dev/null 2>&1
echo "[DONE]"

#
# Because Transmission runs in a container we've to make sure we've a proper
# listener on 0.0.0.0. We also have to deal with the port which by default is
# 9091 but can be changed by the user.
#

printf "Get listener port... "
PORT=$(sed -n '/^port *=/{s/port *= *//p;q}' ${CONFIG})
LISTENER="-s 0.0.0.0:${PORT:=9091}"
echo "[${PORT}]"

#
# Finally, start Transmission.
#

echo "Starting Transmission..."
exec su -p ${USER} -c "transmission-daemon -g $(dirname ${CONFIG}) -f"
