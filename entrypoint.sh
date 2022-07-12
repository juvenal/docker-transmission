#!/bin/sh

#
# Display settings on standard out.
#

USER="sabnzbd"

echo "SABnzbd settings"
echo "=================="
echo
echo "  User:    ${USER}"
echo "  UID:     ${SABNZBD_UID:=666}"
echo "  GID:     ${SABNZBD_GID:=666}"
echo "  CHMOD:   ${CHMOD:=false}"
echo
echo "  Config:  ${CONFIG:=/etc/sabnzbd/config.ini}"
echo

#
# Change UID / GID of SABnzbd user.
#

printf "Updating UID / GID if needed... "
[[ $(id -u ${USER}) == ${SABNZBD_UID} ]] || usermod  -o -u ${SABNZBD_UID} ${USER}
[[ $(id -g ${USER}) == ${SABNZBD_GID} ]] || groupmod -o -g ${SABNZBD_GID} ${USER}
echo "[DONE]"

#
# Set directory permissions.
#

printf "Set permissions... "
touch ${CONFIG}
chown -R ${USER}:${USER} \
      /home/sabnzbd \
      /opt/sabnzbd \
      > /dev/null 2>&1
[[ "${CHMOD}" == "false" ]] || \
    chown -R ${USER}:${USER} \
          /etc/sabnzbd \
          /mnt/sabnzbd/watch \
	  /mnt/sabnzbd/downloads \
          > /dev/null 2>&1
echo "[DONE]"

#
# Because SABnzbd runs in a container we've to make sure we've a proper
# listener on 0.0.0.0. We also have to deal with the port which by default is
# 8080 but can be changed by the user.
#

printf "Get listener port... "
PORT=$(sed -n '/^port *=/{s/port *= *//p;q}' ${CONFIG})
LISTENER="-s 0.0.0.0:${PORT:=8080}"
echo "[${PORT}]"

#
# Finally, start SABnzbd.
#

echo "Starting SABnzbd..."
exec su -p ${USER} -c "python -OO /opt/sabnzbd/SABnzbd.py -b 0 -f ${CONFIG} ${LISTENER}"
