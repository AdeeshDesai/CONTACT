#!/usr/bin/env bash
# CONTACT | task: barbed_spike | modality: vistac
# usage: bash training/barbed_spike/vistac.sh [seed] [hydra overrides...]
cd "$(dirname "$0")/../.."
python train.py --config-name=train_diffusion_workspace_disassembly.yaml \
    task=vistac_disassembly \
    dataset_path=data/barbed_spike \
    isaacgym_cfg_name=isaacgym_config_barbed_spike.yaml \
    exp_name=vistac_barbed_spike_50 \
    logging.project=dp_barbed_spike \
    hydra.run.dir=data/outputs/vistac_barbed_spike_50/${1:-42} \
    training.seed=${1:-42} "${@:2}"
