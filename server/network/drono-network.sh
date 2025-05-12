#!/bin/bash

# Network namespace configuration for Drono USB devices
# This script creates an isolated network namespace for USB devices

# Configuration
NAMESPACE="drono-usb"
BRIDGE="drono-br0"
VETH_HOST="drono-veth0"
VETH_NS="drono-veth1"
IP_RANGE="10.0.0.0/24"
IP_HOST="10.0.0.1"
IP_NS="10.0.0.2"

# Function to create network namespace
create_namespace() {
    echo "Creating network namespace $NAMESPACE..."
    ip netns add $NAMESPACE
    
    # Create virtual ethernet pair
    ip link add $VETH_HOST type veth peer name $VETH_NS
    
    # Move one end to namespace
    ip link set $VETH_NS netns $NAMESPACE
    
    # Create bridge
    ip link add $BRIDGE type bridge
    ip link set $BRIDGE up
    
    # Add host end to bridge
    ip link set $VETH_HOST up
    ip link set $VETH_HOST master $BRIDGE
    
    # Configure namespace end
    ip netns exec $NAMESPACE ip link set lo up
    ip netns exec $NAMESPACE ip link set $VETH_NS up
    ip netns exec $NAMESPACE ip addr add $IP_NS/24 dev $VETH_NS
    ip netns exec $NAMESPACE ip route add default via $IP_HOST
    
    # Configure host end
    ip addr add $IP_HOST/24 dev $BRIDGE
    
    # Enable forwarding
    echo 1 > /proc/sys/net/ipv4/ip_forward
    ip netns exec $NAMESPACE echo 1 > /proc/sys/net/ipv4/ip_forward
    
    # Add iptables rules for isolation
    iptables -t nat -A POSTROUTING -s $IP_RANGE -o eth0 -j MASQUERADE
    iptables -A FORWARD -i $BRIDGE -o eth0 -j ACCEPT
    iptables -A FORWARD -i eth0 -o $BRIDGE -m state --state RELATED,ESTABLISHED -j ACCEPT
}

# Function to delete network namespace
delete_namespace() {
    echo "Deleting network namespace $NAMESPACE..."
    
    # Remove iptables rules
    iptables -t nat -D POSTROUTING -s $IP_RANGE -o eth0 -j MASQUERADE
    iptables -D FORWARD -i $BRIDGE -o eth0 -j ACCEPT
    iptables -D FORWARD -i eth0 -o $BRIDGE -m state --state RELATED,ESTABLISHED -j ACCEPT
    
    # Remove bridge
    ip link set $BRIDGE down
    ip link delete $BRIDGE
    
    # Remove namespace
    ip netns delete $NAMESPACE
}

# Function to move USB device to namespace
move_usb_to_namespace() {
    local device_id=$1
    echo "Moving USB device $device_id to namespace $NAMESPACE..."
    
    # Get USB device path
    local usb_path=$(readlink -f /sys/bus/usb/devices/$device_id)
    
    # Move device to namespace
    ip netns exec $NAMESPACE bash -c "
        echo $usb_path > /sys/bus/usb/drivers/usb/unbind
        echo $usb_path > /sys/bus/usb/drivers/usb/bind
    "
}

# Main script logic
case "$1" in
    start)
        create_namespace
        ;;
    stop)
        delete_namespace
        ;;
    move)
        if [ -z "$2" ]; then
            echo "Usage: $0 move <device_id>"
            exit 1
        fi
        move_usb_to_namespace $2
        ;;
    *)
        echo "Usage: $0 {start|stop|move <device_id>}"
        exit 1
        ;;
esac

exit 0 

# Network namespace configuration for Drono USB devices
# This script creates an isolated network namespace for USB devices

# Configuration
NAMESPACE="drono-usb"
BRIDGE="drono-br0"
VETH_HOST="drono-veth0"
VETH_NS="drono-veth1"
IP_RANGE="10.0.0.0/24"
IP_HOST="10.0.0.1"
IP_NS="10.0.0.2"

# Function to create network namespace
create_namespace() {
    echo "Creating network namespace $NAMESPACE..."
    ip netns add $NAMESPACE
    
    # Create virtual ethernet pair
    ip link add $VETH_HOST type veth peer name $VETH_NS
    
    # Move one end to namespace
    ip link set $VETH_NS netns $NAMESPACE
    
    # Create bridge
    ip link add $BRIDGE type bridge
    ip link set $BRIDGE up
    
    # Add host end to bridge
    ip link set $VETH_HOST up
    ip link set $VETH_HOST master $BRIDGE
    
    # Configure namespace end
    ip netns exec $NAMESPACE ip link set lo up
    ip netns exec $NAMESPACE ip link set $VETH_NS up
    ip netns exec $NAMESPACE ip addr add $IP_NS/24 dev $VETH_NS
    ip netns exec $NAMESPACE ip route add default via $IP_HOST
    
    # Configure host end
    ip addr add $IP_HOST/24 dev $BRIDGE
    
    # Enable forwarding
    echo 1 > /proc/sys/net/ipv4/ip_forward
    ip netns exec $NAMESPACE echo 1 > /proc/sys/net/ipv4/ip_forward
    
    # Add iptables rules for isolation
    iptables -t nat -A POSTROUTING -s $IP_RANGE -o eth0 -j MASQUERADE
    iptables -A FORWARD -i $BRIDGE -o eth0 -j ACCEPT
    iptables -A FORWARD -i eth0 -o $BRIDGE -m state --state RELATED,ESTABLISHED -j ACCEPT
}

# Function to delete network namespace
delete_namespace() {
    echo "Deleting network namespace $NAMESPACE..."
    
    # Remove iptables rules
    iptables -t nat -D POSTROUTING -s $IP_RANGE -o eth0 -j MASQUERADE
    iptables -D FORWARD -i $BRIDGE -o eth0 -j ACCEPT
    iptables -D FORWARD -i eth0 -o $BRIDGE -m state --state RELATED,ESTABLISHED -j ACCEPT
    
    # Remove bridge
    ip link set $BRIDGE down
    ip link delete $BRIDGE
    
    # Remove namespace
    ip netns delete $NAMESPACE
}

# Function to move USB device to namespace
move_usb_to_namespace() {
    local device_id=$1
    echo "Moving USB device $device_id to namespace $NAMESPACE..."
    
    # Get USB device path
    local usb_path=$(readlink -f /sys/bus/usb/devices/$device_id)
    
    # Move device to namespace
    ip netns exec $NAMESPACE bash -c "
        echo $usb_path > /sys/bus/usb/drivers/usb/unbind
        echo $usb_path > /sys/bus/usb/drivers/usb/bind
    "
}

# Main script logic
case "$1" in
    start)
        create_namespace
        ;;
    stop)
        delete_namespace
        ;;
    move)
        if [ -z "$2" ]; then
            echo "Usage: $0 move <device_id>"
            exit 1
        fi
        move_usb_to_namespace $2
        ;;
    *)
        echo "Usage: $0 {start|stop|move <device_id>}"
        exit 1
        ;;
esac

exit 0 