#!/usr/bin/env bash
# CONTACT | task: tight_plug | modality: vision
# usage: bash training/tight_plug/vision.sh [seed] [hydra overrides...]
cd "$(dirname "$0")/../.."
python train.py --config-name=train_diffusion_workspace_disassembly.yaml \
    task=vision_disassembly \
    dataset_path=data/tight_plug \
    isaacgym_cfg_name=isaacgym_config_tightplug.yaml \
    exp_name=vision_tight_plug_50 \
    logging.project=dp_tight_plug \
    hydra.run.dir=data/outputs/vision_tight_plug_50/${1:-42} \
    training.seed=${1:-42} "${@:2}"
