#!/usr/bin/env bash
# CONTACT | task: loose_plug | modality: vision
# usage: bash training/loose_plug/vision.sh [seed] [hydra overrides...]
cd "$(dirname "$0")/../.."
python train.py --config-name=train_diffusion_workspace_disassembly.yaml \
    task=vision_disassembly \
    dataset_path=data/loose_plug \
    isaacgym_cfg_name=isaacgym_config_looseplug.yaml \
    exp_name=vision_loose_plug_50 \
    logging.project=dp_loose_plug \
    hydra.run.dir=data/outputs/vision_loose_plug_50/${1:-42} \
    training.seed=${1:-42} "${@:2}"
