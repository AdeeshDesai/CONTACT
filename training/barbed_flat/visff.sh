#!/usr/bin/env bash
# CONTACT | task: barbed_flat | modality: visff
# usage: bash training/barbed_flat/visff.sh [seed] [hydra overrides...]
cd "$(dirname "$0")/../.."
python train.py --config-name=train_diffusion_workspace_disassembly.yaml \
    task=visff_disassembly \
    dataset_path=data/barbed_flat \
    isaacgym_cfg_name=isaacgym_config_barbed_flat.yaml \
    exp_name=visff_barbed_flat_50 \
    logging.project=dp_barbed_flat \
    hydra.run.dir=data/outputs/visff_barbed_flat_50/${1:-42} \
    training.seed=${1:-42} "${@:2}"
