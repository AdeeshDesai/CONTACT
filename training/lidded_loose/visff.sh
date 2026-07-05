#!/usr/bin/env bash
# CONTACT | task: lidded_loose | modality: visff
# usage: bash training/lidded_loose/visff.sh [seed] [hydra overrides...]
cd "$(dirname "$0")/../.."
python train.py --config-name=train_diffusion_workspace_disassembly.yaml \
    task=visff_disassembly \
    dataset_path=data/lidded_loose \
    isaacgym_cfg_name=isaacgym_config_liddedloose.yaml \
    exp_name=visff_lidded_loose_50 \
    logging.project=dp_lidded_loose \
    hydra.run.dir=data/outputs/visff_lidded_loose_50/${1:-42} \
    training.seed=${1:-42} "${@:2}"
