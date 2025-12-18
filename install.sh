#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_msg() {
    echo -e "${GREEN}[+]${NC} $1"
}

print_err() {
    echo -e "${RED}[!]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[*]${NC} $1"
}

# Check root (for Kali Linux)
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_msg "Root access detected (Kali Linux)"
        IS_ROOT=true
    else
        print_warn "Non-root mode detected (Termux/Linux User)"
        IS_ROOT=false
    fi
}

# Detect platform
detect_platform() {
    if [[ -d "/data/data/com.termux" ]]; then
        print_msg "Termux environment detected"
        PLATFORM="termux"
    elif [[ -f "/etc/debian_version" ]] || [[ -f "/etc/kali-release" ]]; then
        print_msg "Kali Linux/Debian detected"
        PLATFORM="kali"
    else
        print_warn "Unknown platform, trying Linux install..."
        PLATFORM="linux"
    fi
}

# Install for Termux
install_termux() {
    print_msg "Updating Termux packages..."
    pkg update -y
    
    print_msg "Installing dependencies..."
    pkg install wget proot -y
    
    # Create Cloudflared directory
    CLOUDFLARED_DIR="$PREFIX/opt/cloudflared"
    mkdir -p $CLOUDFLARED_DIR
    
    # Download latest cloudflared
    print_msg "Downloading cloudflared for Termux..."
    ARCH=$(uname -m)
    
    case $ARCH in
        aarch64)
            ARCH_TYPE="arm64"
            ;;
        armv7l|armv8l)
            ARCH_TYPE="arm"
            ;;
        x86_64)
            ARCH_TYPE="amd64"
            ;;
        i686|i386)
            ARCH_TYPE="386"
            ;;
        *)
            ARCH_TYPE="amd64"
            ;;
    esac
    
    # Download binary
    wget -q "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH_TYPE}" -O $CLOUDFLARED_DIR/cloudflared
    
    # Make executable
    chmod +x $CLOUDFLARED_DIR/cloudflared
    
    # Create symlink
    ln -sf $CLOUDFLARED_DIR/cloudflared $PREFIX/bin/cloudflared 2>/dev/null
    
    print_msg "Termux installation complete!"
}

# Install for Kali Linux
install_kali() {
    print_msg "Updating Kali Linux packages..."
    apt update -y
    
    print_msg "Installing dependencies..."
    apt install wget curl -y
    
    # Download and install cloudflared
    print_msg "Downloading cloudflared for Kali Linux..."
    
    # Get latest version
    LATEST_VERSION=$(curl -s https://api.github.com/repos/cloudflare/cloudflared/releases/latest | grep tag_name | cut -d '"' -f 4)
    
    # Download .deb package
    wget -q "https://github.com/cloudflare/cloudflared/releases/${LATEST_VERSION}/download/cloudflared-linux-amd64.deb" -O /tmp/cloudflared.deb
    
    # Install .deb package
    dpkg -i /tmp/cloudflared.deb 2>/dev/null || {
        print_warn "Fixing dependencies..."
        apt --fix-broken install -y
        dpkg -i /tmp/cloudflared.deb
    }
    
    # Alternative method if .deb fails
    if ! command -v cloudflared &>/dev/null; then
        print_warn "Using binary install method..."
        wget -q "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" -O /usr/local/bin/cloudflared
        chmod +x /usr/local/bin/cloudflared
    fi
    
    print_msg "Kali Linux installation complete!"
}

# Install for other Linux
install_linux() {
    print_msg "Installing for generic Linux..."
    
    # Check architecture
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            ARCH_TYPE="amd64"
            ;;
        aarch64)
            ARCH_TYPE="arm64"
            ;;
        armv7l)
            ARCH_TYPE="arm"
            ;;
        *)
            print_err "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac
    
    # Download binary
    print_msg "Downloading cloudflared..."
    wget -q "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH_TYPE}" -O /tmp/cloudflared
    
    # Make executable and move to bin
    chmod +x /tmp/cloudflared
    
    if [[ $IS_ROOT == true ]]; then
        mv /tmp/cloudflared /usr/local/bin/
        print_msg "Installed to /usr/local/bin/cloudflared"
    else
        mkdir -p ~/.local/bin
        mv /tmp/cloudflared ~/.local/bin/
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
        print_msg "Installed to ~/.local/bin/cloudflared"
        print_warn "Please restart terminal or run: source ~/.bashrc"
    fi
}

# Verify installation
verify_installation() {
    print_msg "Verifying installation..."
    
    if command -v cloudflared &>/dev/null; then
        CLOUDFLARED_VERSION=$(cloudflared --version 2>/dev/null || cloudflared version 2>/dev/null || echo "Unknown")
        print_msg "✓ Cloudflared installed successfully!"
        print_msg "  Version: $CLOUDFLARED_VERSION"
        print_msg "  Run 'cloudflared --help' to get started"
        
        # Show usage examples
        echo -e "\n${YELLOW}Usage Examples:${NC}"
        echo "  cloudflared tunnel login"
        echo "  cloudflared tunnel create my-tunnel"
        echo "  cloudflared tunnel run my-tunnel"
        echo "  cloudflared proxy-dns"
        
    else
        print_err "Installation failed!"
        exit 1
    fi
}

# Main installation function
main() {
    echo -e "${GREEN}Cloudflared Multi-Platform Installer${NC}"
    echo "======================================"
    
    # Check platform
    detect_platform
    
    # Check root
    check_root
    
    # Install based on platform
    case $PLATFORM in
        termux)
            install_termux
            ;;
        kali)
            install_kali
            ;;
        linux)
            install_linux
            ;;
        *)
            print_err "Unsupported platform"
            exit 1
            ;;
    esac
    
    # Verify installation
    verify_installation
    
    print_msg "Installation completed successfully! 🚀"
}

# Run main function
main