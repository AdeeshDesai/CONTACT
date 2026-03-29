#!/bin/bash
#SBATCH --job-name=BFWR50_44
#SBATCH --output=logs/%x_%j.out
#SBATCH --error=logs/%x_%j.err
#SBATCH --account=shey
#SBATCH --gres=gpu:1
#SBATCH --partition=a30
#SBATCH --mem=120G
#SBATCH --qos=standby
#SBATCH --cpus-per-task=8
#SBATCH --time=4:00:00


module load monitor

monitor cpu memory >cpu-memory.log &
MEM_PID=


# Run the commands inside the Apptainer container
apptainer exec --nv /scratch/gilbreth/desai274/CONTACT/apptainer/tvb.sif bash -c "
    source ~/.bashrc
    conda activate tacsl
    cd /scratch/gilbreth/desai274/CONTACT
    python train.py         --config-name=train_diffusion_workspace_disassembly.yaml         task=vistac_pih_vision_tactile_onecam_disassembly         exp_name=BFWR50         dataset_path=/scratch/gilbreth/desai274/CONTACT/data/barbed_flat         isaacgym_cfg_name=isaacgym_config_barbed_flat.yaml         training.seed=44         training.num_epochs=500         task.dataset.max_train_episodes=50         hydra.run.dir=data/outputs/BFWR50/44_1         logging.project=barbedflat_44_v1 
"

kill -s INT 

