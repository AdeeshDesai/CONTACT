#!/bin/bash

set -e  # Exit on any error

echo "=========================================="
echo "CONTACT Installation Script"
echo "=========================================="

# Check if conda or mamba is available
if command -v mamba &> /dev/null; then
    CONDA_CMD="mamba"
    echo "✓ Found mamba"
elif command -v conda &> /dev/null; then
    CONDA_CMD="conda"
    echo "✓ Found conda"
else
    echo "⚠ conda/mamba not found. Installing Miniforge3..."
    
    # Download Miniforge
    wget https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh
    
    # Install Miniforge
    bash Miniforge3-Linux-x86_64.sh -b -p $HOME/miniforge3
    
    # Initialize conda
    $HOME/miniforge3/bin/conda init bash
    
    # Source bashrc to make conda available
    source ~/.bashrc
    
    CONDA_CMD="$HOME/miniforge3/bin/conda"
    
    echo "✓ Miniforge3 installed successfully"
    echo "Please restart your terminal or run: source ~/.bashrc"
fi

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

# Get conda base path early so we can use it as the default env path
CONDA_BASE="$("$CONDA_CMD" info --base 2>/dev/null | tail -n 1 | awk '{print $NF}')"

# Function to prompt the user for the Miniforge/conda home directory.
# The environment is always named "contact" and will be created at
# <miniforge_home>/envs/contact. Press Enter to accept the detected default.
# In CI mode (CI=true), the default is used automatically without prompting.
get_conda_env_path() {
    local default_home="$CONDA_BASE"

    echo ""
    echo "=========================================="
    echo "Conda Environment Path"
    echo "=========================================="
    echo "Detected Miniforge/conda home: $default_home"

    if [ "${CI:-false}" = "true" ]; then
        MINIFORGE_HOME="$default_home"
        echo "CI mode: using default Miniforge home"
    else
        read -rp "Enter Miniforge home directory (press Enter to use default): " user_home
        if [ -z "$user_home" ]; then
            MINIFORGE_HOME="$default_home"
        else
            MINIFORGE_HOME="$user_home"
        fi
    fi

    CONDA_ENV_PATH="$MINIFORGE_HOME/envs/${CONDA_ENV_NAME:-contact}"
    echo "✓ Environment will be created at: $CONDA_ENV_PATH"
}

echo ""
echo "=========================================="
echo "Setting up CONTACT environment"
echo "=========================================="

get_conda_env_path

# Create conda environment at the chosen path
echo "Creating Python 3.8 environment at '$CONDA_ENV_PATH'..."
$CONDA_CMD create --prefix "$CONDA_ENV_PATH" python=3.8 -y

source "$CONDA_BASE/etc/profile.d/conda.sh"

# Activate environment
conda activate "$CONDA_ENV_PATH"

echo ""
echo "=========================================="
echo "Installing IsaacGym TacSL"
echo "=========================================="

if [ "${CI:-false}" = "true" ]; then
    echo "⏭ Skipping IsaacGym install in CI mode"
else
    # Check if IsaacGym is already downloaded
    if [ ! -d "$PARENT_DIR/IsaacGym_Preview_TacSL_Package" ]; then
        echo "⚠ IsaacGym_Preview_TacSL_Package not found in parent directory."
        echo "Please download it from: https://drive.google.com/file/d/13dFRF9EXpzIWaJF2Z6f7BsuPUGQkPE8v/view?usp=sharing"
        echo "Extract it to: $PARENT_DIR"
        echo "Then run this script again."
        exit 1
    else
        echo "✓ Found IsaacGym_Preview_TacSL_Package"
        pip install -e "$PARENT_DIR/IsaacGym_Preview_TacSL_Package/isaacgym/python/"
    fi
fi

echo ""
echo "=========================================="
echo "Cloning repositories"
echo "=========================================="

# Clone IsaacGymEnvs
if [ ! -d "$PARENT_DIR/manifeel-isaacgymenvs" ]; then
    echo "Cloning manifeel-isaacgymenvs (IsaacGymEnvs + TacSL)..."
    cd "$PARENT_DIR"
    git clone https://github.com/purdue-mars/manifeel-isaacgymenvs.git
    cd manifeel-isaacgymenvs
    pip install -e .
else
    echo "✓ manifeel-isaacgymenvs already exists"
    cd "$PARENT_DIR/manifeel-isaacgymenvs"
    pip install -e .
fi

# Clone Diffusion Policy
if [ ! -d "$PARENT_DIR/diffusion_policy" ]; then
    echo "Cloning diffusion_policy..."
    cd "$PARENT_DIR"
    git clone https://github.com/real-stanford/diffusion_policy.git
    cd diffusion_policy
    pip install -e .
else
    echo "✓ diffusion_policy already exists"
    cd "$PARENT_DIR/diffusion_policy"
    pip install -e .
fi

echo ""
echo "=========================================="
echo "Installing CONTACT task files"
echo "=========================================="

# Copy CONTACT task files into manifeel-isaacgymenvs so they are importable
echo "Copying CONTACT task files into manifeel-isaacgymenvs..."
cp "$SCRIPT_DIR"/isaacgymenvs/tasks/tacsl/*.py "$PARENT_DIR/manifeel-isaacgymenvs/isaacgymenvs/tasks/tacsl/"
echo "✓ CONTACT task files installed"

# Link CONTACT assets into manifeel-isaacgymenvs so IsaacGym can find them
echo "Linking CONTACT assets into manifeel-isaacgymenvs..."
# Link industreal URDFs and meshes
cp -r "$SCRIPT_DIR"/assets/industreal/urdf/* "$PARENT_DIR/manifeel-isaacgymenvs/assets/industreal/urdf/" 2>/dev/null || true
cp -r "$SCRIPT_DIR"/assets/industreal/mesh/contact_mesh "$PARENT_DIR/manifeel-isaacgymenvs/assets/industreal/mesh/" 2>/dev/null || true
# Link tacsl assets (Disassemble.yaml and others)
cp "$SCRIPT_DIR"/assets/tacsl/yaml/Disassemble.yaml "$PARENT_DIR/manifeel-isaacgymenvs/assets/tacsl/yaml/" 2>/dev/null || true
echo "✓ CONTACT assets installed"

echo ""
echo "=========================================="
echo "Installing CONTACT"
echo "=========================================="

# Install CONTACT
cd "$SCRIPT_DIR"
pip install -e .

# Install additional dependencies
echo "Installing additional dependencies..."
pip install -r "$SCRIPT_DIR/requirements.txt"

echo ""
echo "=========================================="
echo "Installation Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Download IsaacGym_Preview_TacSL_Package (if not already done)"
echo "   from: https://drive.google.com/file/d/13dFRF9EXpzIWaJF2Z6f7BsuPUGQkPE8v/view?usp=sharing"
echo "2. Download the CONTACT dataset from:"
echo "   https://drive.google.com/drive/folders/1FqhPtE4S8JfbGgZU9uFjm-rjhGslpqEy"
echo "   and place it in CONTACT/data/"
echo ""
echo "To activate the environment:"
echo "  conda activate $CONDA_ENV_PATH"
echo ""
