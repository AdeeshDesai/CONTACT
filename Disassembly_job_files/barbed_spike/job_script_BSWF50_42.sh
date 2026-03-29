#!/bin/bash
#SBATCH --job-name=BSWF50_42
#SBATCH --output=logs/%x_%j.out
#SBATCH --error=logs/%x_%j.err
#SBATCH --account=shey
#SBATCH --gres=gpu:1
#SBATCH --partition=a30
#SBATCH --mem=120G
#SBATCH --qos=normal
#SBATCH --cpus-per-task=8
#SBATCH --time=40:00:00


module load monitor

monitor cpu memory >cpu-memory.log &
MEM_PID=


# Run the commands inside the Apptainer container
apptainer exec --nv /scratch/gilbreth/desai274/CONTACT/apptainer/tvb.sif bash -c "
    source ~/.bashrc
    conda activate tacsl
    cd /scratch/gilbreth/desai274/CONTACT
    python train.py         --config-name=train_diffusion_workspace_disassembly.yaml         task=vision_tacff_disassembly         exp_name=BSWF50         dataset_path=/scratch/gilbreth/desai274/CONTACT/data/barbed_spike         isaacgym_cfg_name=isaacgym_config_barbed_spike.yaml         training.seed=42         training.num_epochs=500         task.dataset.max_train_episodes=50         hydra.run.dir=data/outputs/BSWF50/42_1         logging.project=barbedspike_42_v1 
"

kill -s INT 

