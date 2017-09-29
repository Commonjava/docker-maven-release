#!/bin/bash

# We may need a special docker network (bridge-mode so
# your containers can still see the outside world). This
# lets containers communicate with one another, which from
# what I can tell isn't allowed with the normal docker0
# bridge.
DOCKER_NET=${DOCKER_NET:-ci-network}


export gwip=$(docker network inspect ${DOCKER_NET} --format '{{range .IPAM.Config}}{{.Gateway}}{{end}}')
export ifc=$(ip -4 addr show | grep -B1 ${gwip} | head -1 | awk '{print $2}' | sed 's/://')

firewall-cmd --permanent --zone=trusted --add-interface=${ifc}
ifdown ${ifc} && ifup ${ifc}

echo "Zone of ${ifc} is:"
firewall-cmd --get-zone-of-interface=${ifc}

