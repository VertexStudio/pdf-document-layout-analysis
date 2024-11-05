#!/bin/bash

# Usage: ./strict_isolate.sh <container_name_or_id> <container_port>
# Example: ./strict_isolate.sh pdf-document-layout-analysis 5060

set -e

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <container_name_or_id> <container_port>"
    exit 1
fi

CONTAINER_NAME_OR_ID=$1
CONTAINER_PORT=$2

# Get container IP
CONTAINER_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$CONTAINER_NAME_OR_ID")

if [ -z "$CONTAINER_IP" ]; then
    echo "Failed to retrieve IP address for container $CONTAINER_NAME_OR_ID"
    exit 1
fi

# Clean up any existing rules for this container
echo "Cleaning up existing rules for $CONTAINER_IP..."
iptables-save | grep "$CONTAINER_IP" | while read -r rule; do
    iptables -D DOCKER-USER $rule 2>/dev/null || true
done

# Only two rules needed:
# 1. Allow incoming traffic to the specified port
iptables -I DOCKER-USER -p tcp --dport "$CONTAINER_PORT" -d "$CONTAINER_IP" -j ACCEPT

# 2. Block EVERYTHING else from this container
iptables -I DOCKER-USER -s "$CONTAINER_IP" -j DROP

echo "Strict container isolation applied:"
echo " - Container: $CONTAINER_NAME_OR_ID"
echo " - IP: $CONTAINER_IP"
echo " - Only allowing incoming connections to port $CONTAINER_PORT"
echo " - All outgoing connections blocked"

# Display the rules
echo -e "\nDocker user chain rules:"
iptables -L DOCKER-USER -v -n

cat << EOF

To verify isolation:
1. Test allowed incoming: curl http://localhost:$CONTAINER_PORT
2. Verify NO outbound access: 
   docker exec $CONTAINER_NAME_OR_ID ping 8.8.8.8    # Should fail
   docker exec $CONTAINER_NAME_OR_ID curl google.com  # Should fail

To remove these rules:
iptables -D DOCKER-USER -p tcp --dport $CONTAINER_PORT -d $CONTAINER_IP -j ACCEPT
iptables -D DOCKER-USER -s $CONTAINER_IP -j DROP
EOF
