#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' 

print_logo() {
    echo -e "${CYAN}"
    cat << "EOF"
   ██████╗  ██████╗      ██████╗ ███╗   ██╗     █████╗ ██╗██████╗ ██████╗ ██╗      █████╗ ███╗   ██╗███████╗███████╗
  ██╔════╝ ██╔═══██╗    ██╔═══██╗████╗  ██║    ██╔══██╗██║██╔══██╗██╔══██╗██║     ██╔══██╗████╗  ██║██╔════╝██╔════╝
  ██║  ███╗██║   ██║    ██║   ██║██╔██╗ ██║    ███████║██║██████╔╝██████╔╝██║     ███████║██╔██╗ ██║█████╗  ███████╗
  ██║   ██║██║   ██║    ██║   ██║██║╚██╗██║    ██╔══██║██║██╔══██╗██╔═══╝ ██║     ██╔══██║██║╚██╗██║██╔══╝  ╚════██║
  ╚██████╔╝╚██████╔╝    ╚██████╔╝██║ ╚████║    ██║  ██║██║██║  ██║██║     ███████╗██║  ██║██║ ╚████║███████╗███████║
   ╚═════╝  ╚═════╝      ╚═════╝ ╚═╝  ╚═══╝    ╚═╝  ╚═╝╚═╝╚═╝  ╚═╝╚═╝     ╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝╚══════╝
EOF
    echo -e "${NC}"
}

log_info() {
    echo -e "${BLUE}[*] INFO :: $1${NC}"
}

log_success() {
    echo -e "${GREEN}[✓] SUCCESS :: $1${NC}"
}

log_error() {
    echo -e "${RED}[✗] ERROR :: $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}[!] WARNING :: $1${NC}"
}

log_step() {
    echo -e "${CYAN}[*] STEP :: $1${NC}"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

validate_project_name() {
    local name="$1"
    
    if [[ "$name" =~ [[:space:]] ]]; then
        log_error "Project name cannot contain spaces"
        return 1
    fi
    
    if [[ "$name" =~ [A-Z] ]]; then
        log_error "Project name cannot contain uppercase letters"
        return 1
    fi
    
    return 0
}

update_import_paths() {
    local old_name="$1"
    local new_name="$2"
    local dir="$3"
    
    log_step "Updating import paths in source files..."
    
    if ! find "$dir" -type f -name "*.go" -exec grep -l "import.*\"$old_name" {} \; | xargs -r sed -i "s|\"$old_name|\"$new_name|g" > /dev/null 2>&1; then
        log_warning "Some import paths may not have been updated properly"
    else
        log_success "Updated standard import paths in source files"
    fi
    
    if ! find "$dir" -type f -name "*.go" -exec grep -l "import.*\"$old_name/core" {} \; | xargs -r sed -i "s|\"$old_name/core|\"$new_name/core|g" > /dev/null 2>&1; then
        log_warning "Some core import paths may not have been updated properly"
    else
        log_success "Updated core import paths in source files"
    fi
}

setup_goa() {
    log_step "Checking for Git installation..."
    if ! command_exists git; then
        log_error "Git is not installed on your system."
        if command_exists apt-get; then
            log_info "You can install Git using: sudo apt-get install git"
        elif command_exists yum; then
            log_info "You can install Git using: sudo yum install git"
        elif command_exists brew; then
            log_info "You can install Git using: brew install git"
        else
            log_info "Please install Git from https://git-scm.com/downloads"
        fi
        return 1
    fi
    log_success "Git is installed"
    
    log_step "Checking for Go installation..."
    if ! command_exists go; then
        log_error "Go is not installed on your system."
        if command_exists apt-get; then
            log_info "You can install Go using: sudo apt-get install golang"
        elif command_exists yum; then
            log_info "You can install Go using: sudo yum install golang"
        elif command_exists brew; then
            log_info "You can install Go using: brew install go"
        else
            log_info "Please install Go from https://golang.org/dl/"
        fi
        return 1
    fi
    
    GO_VERSION=$(go version | grep -oE 'go[0-9]+\.[0-9]+\.[0-9]+' | cut -c 3-)
    log_success "Go $GO_VERSION is installed"
    
    echo ""
    log_step "Project Setup"
    DEFAULT_NAME=$(basename "$(pwd)")
    
    while true; do
        read -rp "Enter project name (default: $DEFAULT_NAME): " PROJECT_NAME
        if [ -z "$PROJECT_NAME" ]; then
            PROJECT_NAME="$DEFAULT_NAME"
        fi
        
        if validate_project_name "$PROJECT_NAME"; then
            break
        else
            log_warning "Please enter a valid project name (lowercase letters, no spaces)"
        fi
    done
    
    read -rp "Use current directory? (Y/n): " USE_CURRENT_DIR
    if [ -z "$USE_CURRENT_DIR" ] || [ "$USE_CURRENT_DIR" = "y" ] || [ "$USE_CURRENT_DIR" = "Y" ]; then
        PROJECT_DIR="$(pwd)"
        IN_CURRENT_DIR=true
    else
        PROJECT_DIR="$(pwd)/$PROJECT_NAME"
        IN_CURRENT_DIR=false
        
        if [ ! -d "$PROJECT_DIR" ]; then
            mkdir -p "$PROJECT_DIR"
        fi
    fi
    
    log_step "Cloning Go on Airplanes repository..."
    
    if [ "$IN_CURRENT_DIR" = true ]; then
        TEMP_DIR=$(mktemp -d)
        
        if ! cd "$TEMP_DIR"; then
            log_error "Failed to create temporary directory"
            return 1
        fi
        
        if ! git clone https://github.com/kleeedolinux/goonairplanes.git . > /dev/null 2>&1; then
            log_error "Failed to clone repository"
            cd - > /dev/null || return 1
            return 1
        fi
        
        if ! rsync -a --exclude='.git' ./ "$PROJECT_DIR/"; then
            log_error "Failed to copy files to project directory"
            cd - > /dev/null || return 1
            return 1
        fi
        
        cd - > /dev/null || return 1
        rm -rf "$TEMP_DIR"
    else
        if ! git clone https://github.com/kleeedolinux/goonairplanes.git "$PROJECT_DIR" > /dev/null 2>&1; then
            log_error "Failed to clone repository"
            return 1
        fi
        
        rm -rf "$PROJECT_DIR/.git"
    fi
    
    log_success "Repository cloned successfully"
    
    log_step "Cleaning up unnecessary files..."
    if ! cd "$PROJECT_DIR"; then
        log_error "Failed to change to project directory"
        return 1
    fi
    
    rm -rf img README.md MANIFEST.md BENCHMARK.MD CODE_OF_CONDUCT.md ROADMAP.md SECURITY.md
    
    read -rp "Do you want to keep local documentation? (Y/n): " KEEP_DOCS
    if [ -z "$KEEP_DOCS" ] || [ "$KEEP_DOCS" = "n" ] || [ "$KEEP_DOCS" = "N" ]; then
        rm -rf docs/
        log_success "Documentation removed"
    else
        log_success "Documentation kept"
    fi
    
    rm -rf scripts/
    
    log_success "Cleanup completed"
    
    log_step "Initializing new Git repository..."
    if ! git init > /dev/null 2>&1; then
        log_error "Failed to initialize Git repository"
    else
        git add . > /dev/null 2>&1
        git commit -m "Initial commit: Go on Airplanes project" > /dev/null 2>&1
        log_success "Git repository initialized"
    fi
    
    log_step "Updating project configuration..."
    
    log_step "Installing dependencies..."
    if ! go mod tidy; then
        log_error "Failed to run go mod tidy"
    else
        log_success "Dependencies installed successfully"
    fi
    
    echo ""
    log_success "Setup completed successfully!"
    log_info "Your Go on Airplanes project is ready at: $PROJECT_DIR"
    
    echo ""
    echo -e "${CYAN}To run your application:${NC}"
    echo -e "  cd $PROJECT_DIR"
    echo -e "  go run main.go"
    
    cd - > /dev/null || return 1
    return 0
}

main() {
    print_logo
    echo -e "${CYAN}Go on Airplanes - Setup Wizard${NC}"
    echo -e "${BLUE}Fly high with simple web development${NC}"
    echo ""
    
    setup_goa
    
    if [ $? -ne 0 ]; then
        log_error "Setup failed"
        exit 1
    fi
}

main

echo ""
read -rp "Press Enter to exit..." 