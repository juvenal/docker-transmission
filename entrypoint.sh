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
# Set directory permissions.
#

printf "Set permissions... "
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
# Validate files and accesses as transmission user
#

# Check config file
cat << EOC1 | su -p ${USER} -c "/bin/sh -s"
    printf "Creating default settings file... "
    if [ ! -f /etc/transmission/settings.json ]; then
        cp /etc/default/transmission/settings.json /etc/transmission/settings.json
        echo "Done!"
    else
        echo "Not needed!"
    fi
EOC1

# If provided, update WebUI user and password
cat << EOC2 | su -p ${USER} -c "/bin/sh -s"
    printf "Setting web user and password... "
    if [ ! -z "${WEBUSER}" ] && [ ! -z "${WEBPASS}" ]; then
        sed -i '/rpc-authentication-required/c\    "rpc-authentication-required": true,' /etc/transmission/settings.json
        sed -i "/rpc-username/c\    \"rpc-username\": \"${WEBUSER}\"," /etc/transmission/settings.json
        sed -i "/rpc-password/c\    \"rpc-password\": \"${WEBPASS}\"," /etc/transmission/settings.json
        echo "Done!"
    else
        echo "No change!"
    fi
EOC2

# If provided, update the whitelist allowed rpc hosts
cat << EOC3 | su -p ${USER} -c "/bin/sh -s"
    printf "Setting white list access... "
    if [ ! -z "${WHITELIST}" ]; then
        sed -i '/rpc-whitelist-enabled/c\    "rpc-whitelist-enabled": true,' /etc/transmission/settings.json
        sed -i "/\"rpc-whitelist\"/c\    \"rpc-whitelist\": \"${WHITELIST}\"," /etc/transmission/settings.json
        echo "Done!"
    else
        echo "No change!"
    fi
EOC3

# If provided, define the allowed rpc whitelist hosts
cat << EOC4 | su -p ${USER} -c "/bin/sh -s"
    printf "Setting white list rpc access... "
    if [ ! -z "${HOST_WHITELIST}" ]; then
        sed -i '/rpc-host-whitelist-enabled/c\    "rpc-host-whitelist-enabled": true,' /etc/transmission/settings.json
        sed -i "/\"rpc-host-whitelist\"/c\    \"rpc-host-whitelist\": \"${HOST_WHITELIST}\"," /etc/transmission/settings.json
        echo "Done!"
    else
        echo "No change!"
    fi
EOC4

# If provided, define the peer port to use
cat << EOC5 | su -p ${USER} -c "/bin/sh -s"
    printf "Setting peer port access... "
    if [ ! -z "${PEERPORT}" ]; then
        sed -i "/\"peer-port\"/c\    \"peer-port\": ${PEERPORT}," /etc/transmission/settings.json
        sed -i '/peer-port-random-on-start/c\     "peer-port-random-on-start": false,' /etc/transmission/settings.json
        echo "Done!"
    else
        echo "No change!"
    fi
EOC5

#
# Finally, start Transmission.
#
echo "Starting Transmission..."
exec su -p ${USER} -c "transmission-daemon -g $(dirname ${CONFIG}) -f"
