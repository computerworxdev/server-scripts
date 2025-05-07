#!/bin/sh

. messages.sh

EPEL9=https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
EPEL8=https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm

install_epel() {
    if rpm -q epel-release &>/dev/null; then
	    success "EPEL is already installed."
	    return 0
    fi

    echo "Installing EPEL repository..."
    if ! dnf repolist | grep -q "^epel/"; then
        dnf install -y epel-release || {
            alert "Failed to install epel-release via dnf. Attempting manual install..."
            # Determine OS version
            OS_VERSION=$(rpm -E %rhel)
            if [ "$OS_VERSION" -ge 9 ]; then
                dnf install -y $EPEL9
            elif [ "$OS_VERSION" -eq 8 ]; then
                dnf install -y $EPEL8
            else
                alert "Unsupported OS version. Please install EPEL repository manually."
                exit 1
            fi
        }
    else
        success "EPEL repository is already installed."
    fi

    # Enable EPEL repository
    dnf config-manager --enable epel
}
