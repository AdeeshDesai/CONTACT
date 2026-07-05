#!/usr/bin/env bash
# CONTACT | task: barbed_spike | modality: visff
# usage: bash training/barbed_spike/visff.sh [seed] [hydra overrides...]
cd "$(dirname "$0")/../.."
python train.py --config-name=train_diffusion_workspace_disassembly.yaml \
    task=visff_disassembly \
    dataset_path=data/barbed_spike \
    isaacgym_cfg_name=isaacgym_config_barbed_spike.yaml \
    exp_name=visff_barbed_spike_50 \
    logging.project=dp_barbed_spike \
    hydra.run.dir=data/outputs/visff_barbed_spike_50/${1:-42} \
    training.seed=${1:-42} "${@:2}"
