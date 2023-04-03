#!/bin/bash

# Set default values for variables
VERBOSE=false

MOTD_ARG=""
MOTD_UPDATE=false

LOGGING=false

DAEMON_MTU=false

USERS=()

OS=""

# Parse command-line arguments
while [[ $# -gt 0 ]]
do
    case "$1" in
        -m)
            MOTD_UPDATE=true
            MOTD_ARG="$2"
            shift
            shift
            ;;
        -d|--daemon-mtu)
            DAEMON_MTU=true
            shift
            ;;
        -l|--logging)
            LOGGING=true
            shift
            ;;
        *)
            USERS+=("$1")
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -*)
            echo "Invalid option: $1"
            echo "Usage: $0 [-m <arg>] [-d|--daemon-mtu] [-l|--logging] [-v|--verbose] [user1 user2 ...]"
            exit 1
            ;;
    esac
done



# Print usage message if no arguments are passed
if [[ $# -eq 0 ]]; then
	echo "Usage: sudo $0 [-m \"MOTD message\"] [user1 user2 ...] [-v|--verbose] [-d [MTU value]|--daemon-mtu [MTU value]] [-l [level]|--logging [level]]"
    echo "Usage: $0 [-m MOTD] [-d] [-l] [-v] [USER1 USER2 ...]"
    echo "  -m MOTD          Update the MOTD with the given message"
    echo "  -d, --daemon-mtu Print the current daemon MTU"
    echo "  -l, --logging    Print the current daemon logging level"
    echo "  -v, --verbose    Enable verbose output"
    echo "  USER1 USER2 ...  Add users to the OS and Docker group"
    exit 0
fi



# Detect the Linux distribution
if [ -f /etc/os-release ]; then
    # Modern Linux distributions (since systemd)
    . /etc/os-release
    case $ID in
        "ubuntu")
            OS=$ID
            ;;
        "centos")
            OS=$ID
            ;;
        "arch")
            OS=$ID
            ;;
    esac
else
    echo "Unsupported operating system"
    exit 1
fi



# Set the package manager based on the detected OS
case $OS in
    "ubuntu")
        PM="apt-get"
        ;;
    "centos")
        PM="dnf"
        ;;
    "arch")
        PM="pacman"
        ;;
esac

# Install Docker and Docker Compose using the appropriate package manager
if [ "$VERBOSE" = true ]; then
    echo "Installing Docker and Docker Compose using $PM..."
fi
case "$OS" in
    Arch)
        sudo pacman -Sy docker docker-compose
        ;;
    CentOS)
        sudo yum check-update
        sudo yum install -y docker-ce docker-ce-cli containerd.io
        sudo systemctl start docker
        sudo systemctl enable docker
        sudo curl -L "https://github.com/docker/compose/releases/download/1.28.5/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        ;;
    Ubuntu)
        sudo apt-get update
        sudo apt-get install -y docker.io docker-compose
        ;;
    *)
        echo "Unknown Linux Distribution: $OS"
        exit 1
        ;;
esac



# Add users to the OS and Docker group if no flag is present
if [ "$MOTD_UPDATE" = false ] && [ "$DAEMON_MTU" = false ] && [ "$LOGGING" = false ]; then
    for user in "${USERS[@]}"; do
        if [ "$VERBOSE" = true ]; then
            echo "Adding user $user to the OS and Docker group..."
        fi
        sudo useradd -m -s /bin/bash $user
        sudo usermod -aG docker $user
    done
fi



# Check if the daemon MTU flag is set
if [ "$DAEMON_MTU" = true ]; then
    if [ "$VERBOSE" = true ]; then
        echo "Current daemon MTU:"
    fi
    sudo docker info --format '{{.DockerRootDir}}/mtu' | xargs cat
    exit 0
fi



# Check if the logging flag is set
if [ "$LOGGING" = true ]; then
    if [ "$VERBOSE" = true ]; then
        echo "Current daemon logging level:"
    fi
    sudo docker info --format '{{.LoggingDriver}}'
    exit 0
fi




sudo $PM update
sudo $PM install -y docker.io docker-compose



# Set daemon MTU if the flag is present
if [ -n "$DAEMON_MTU" ]; then
    if [ "$VERBOSE" = true ]; then
        echo "Setting daemon MTU to $DAEMON_MTU..."
    fi
    echo "$DAEMON_MTU" | sudo tee /etc/docker/daemon.json > /dev/null
    sudo systemctl restart docker
fi



# Update the MOTD if the flag is set
if [ "$MOTD_UPDATE" = true ]; then
    if [ "$VERBOSE" = true ]; then
        echo "Updating MOTD with message: $MOTD_ARG"
    fi
    echo "$MOTD_ARG" | sudo tee /etc/motd > /dev/null
fi



# Print variables if verbose flag is set
if [ "$VERBOSE" = true ]; then
    echo "MOTD is set to: $MOTD_UPDATE"
	echo "MOTD argument: $MOTD_ARG"
	echo "Docker Daemon MTU is set to: $DAEMON_MTU"
	echo "Logging is set to: $LOGGING"
	echo "Users that were parsed: ${USERS[@]}"
	echo "Verbose option is set to: $VERBOSE"
fi
