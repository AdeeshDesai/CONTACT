# CONTACT: CONtact-aware TACTile Learning for Robotic Disassembly

[Paper](https://arxiv.org/abs/2603.08560) | [Website (coming soon)]()

CONTACT is a simulation benchmark for investigating the role of tactile sensing in robotic disassembly. It provides five rigid-body disassembly tasks with progressively increasing geometric constraints and contact complexity, implemented in IsaacGym with TacSL-based tactile rendering. Policies are trained using Diffusion Policy with multimodal visuotactile observations.

This codebase is built upon [ManiFeel](https://github.com/purdue-mars/manifeel).

---

## Simulation Tasks

| Task | Name | Description |
|------|------|-------------|
| **S1** | Vertical Pull, Loose Socket | Simple extraction with generous clearance |
| **S2** | Vertical Pull, Tight Socket | Reduced tolerance requiring friction-aware force control |
| **S3** | Loose Plug with Lid | Multi-stage task: disengage lid constraint, then extract |
| **S4** | Vertical Pull, Flat Barb | Asymmetric resistance through flat barb structure |
| **S5** | Vertical Pull, Spike Barb | Spike-shaped barb requiring careful collision avoidance |

Three sensing configurations are evaluated per task:
- **Vision Only** — front + wrist RGB cameras
- **Vision + TacRGB** — cameras + tactile RGB deformation images
- **Vision + TacFF** — cameras + tactile force-field (shear + normal force grid)

---

## 1. Installation

### 1.1 Create Workspace

Create a workspace directory and clone this repository:

```bash
mkdir contact_ws && cd contact_ws
git clone https://github.com/AdeeshDesai/CONTACT.git
```

### 1.2 Download IsaacGym

Download the TacSL-specific IsaacGym binary from [here](https://drive.google.com/file/d/13dFRF9EXpzIWaJF2Z6f7BsuPUGQkPE8v/view?usp=sharing) and extract it into the workspace:

```bash
# From contact_ws/
tar -xvzf IsaacGym_Preview_TacSL_Package.tar.gz
```

### 1.3 Run Installation Script

```bash
cd CONTACT
bash install.sh
```

The script will:
- Create a Python 3.8 conda environment named `contact`
- Install IsaacGym TacSL
- Clone and install [manifeel-isaacgymenvs](https://github.com/purdue-mars/manifeel-isaacgymenvs) (IsaacGymEnvs + TacSL sensors)
- Clone and install [Diffusion Policy](https://github.com/real-stanford/diffusion_policy)
- Install CONTACT and all dependencies

After installation, your workspace should look like:
```
contact_ws/
├── CONTACT/                          # This repository
├── manifeel-isaacgymenvs/            # IsaacGymEnvs + TacSL (cloned by install.sh)
├── IsaacGym_Preview_TacSL_Package/   # IsaacGym binary (downloaded manually)
└── diffusion_policy/                 # Diffusion Policy (cloned by install.sh)
```

---

## 2. Download Dataset

Download the CONTACT demonstration datasets from [Google Drive (link coming soon)]() and place them inside `CONTACT/data/`:

```
CONTACT/
└── data/
    ├── loose_plug/
    ├── tight_plug/
    ├── lidded_loose/
    ├── barbed_flat/
    └── barbed_spike/
```

Each dataset contains 50 teleoperated demonstrations with front camera, wrist camera, tactile RGB, tactile force-field, and end-effector state observations recorded at 10 Hz.

---

## 3. Setup Apptainer for Training

We provide an Apptainer container for reproducible environments across clusters and workstations.

### 3.1 Build the Container

```bash
apptainer build contact.sif contact.def
```

### 3.2 Verify the Setup

```bash
apptainer exec --nv contact.sif bash
source ~/.bashrc
conda activate contact
export LD_LIBRARY_PATH=${CONDA_PREFIX}/lib:${LD_LIBRARY_PATH}
python -c "from isaacgym import gymtorch"
exit
```

If `gymtorch` imports without errors, the setup is complete.

---

## 4. Training on Cluster with Slurm

Example job scripts for each task are provided in `Disassembly_job_files/`. Each task has scripts for three modalities (Vision, Vision+TacRGB, Vision+TacFF) across multiple seeds.

### 4.1 Task Configuration Reference

| Task | Config Name | IsaacGym Config | Dataset Path |
|------|-------------|-----------------|--------------|
| S1 (Loose) | `vistac_pih_multiple_vision_onecam_disassembly` | `isaacgym_config_looseplug.yaml` | `data/loose_plug` |
| S2 (Tight) | `vistac_pih_multiple_vision_onecam_disassembly` | `isaacgym_config_tightplug.yaml` | `data/tight_plug` |
| S3 (Lidded) | `vistac_pih_multiple_vision_onecam_disassembly` | `isaacgym_config_liddedloose.yaml` | `data/lidded_loose` |
| S4 (Barbed Flat) | `vistac_pih_multiple_vision_onecam_disassembly` | `isaacgym_config_barbed_flat.yaml` | `data/barbed_flat` |
| S5 (Barbed Spike) | `vistac_pih_multiple_vision_onecam_disassembly` | `isaacgym_config_barbed_spike.yaml` | `data/barbed_spike` |

### 4.2 Running a Training Job

**Vision Only** (example: Task S4, Barbed Flat, seed 42):

```bash
cd Disassembly_job_files/barbed_flat
chmod +x vision_loose_plug_42.sh
./vision_loose_plug_42.sh
```

**Vision + TacFF** (example: Task S4, Barbed Flat, seed 42):

```bash
cd Disassembly_job_files/barbed_flat
chmod +x vision_ff_loose_plug_42.sh
./vision_ff_loose_plug_42.sh
```

**Vision + TacRGB** (example: Task S4, Barbed Flat, seed 42):

```bash
cd Disassembly_job_files/barbed_flat
chmod +x vision_rgb_loose_plug_42.sh
./vision_rgb_loose_plug_42.sh
```

### 4.3 Custom Training Command

You can also launch training directly. The key parameters are:

```bash
apptainer exec --nv contact.sif bash -c "
    source ~/.bashrc
    conda activate contact
    cd /path/to/CONTACT
    python train.py \
        --config-name=train_diffusion_workspace_disassembly.yaml \
        task=vistac_pih_multiple_vision_onecam_disassembly \
        exp_name=BFW50 \
        dataset_path=data/barbed_flat \
        isaacgym_cfg_name=isaacgym_config_barbed_flat.yaml \
        training.seed=42 \
        training.num_epochs=500 \
        task.dataset.max_train_episodes=50 \
        hydra.run.dir=data/outputs/BFW50/42 \
        logging.project=barbedflat_42
"
```

For **TacFF** modality, use `task=vision_tacff_disassembly` instead.

Logs and checkpoints are saved to `data/outputs/`. Success rates and rollout videos are logged to W&B.

### 4.4 Key Parameters

| Parameter | Description |
|-----------|-------------|
| `task` | Sensing config: `vistac_pih_multiple_vision_onecam_disassembly` (Vision/TacRGB) or `vision_tacff_disassembly` (TacFF) |
| `isaacgym_cfg_name` | Task geometry config (see table above) |
| `dataset_path` | Path to demonstration dataset |
| `training.seed` | Random seed (we use 42, 43, 44) |
| `training.num_epochs` | Training epochs (default: 500) |
| `task.dataset.max_train_episodes` | Number of demos to use (default: 50) |

---

## 5. Training Locally

For local machines (PC/workstation), use `scripts/run_local.sh`:

```bash
chmod +x scripts/run_local.sh

# Vision Only - Barbed Flat
DATASET_PATH=data/barbed_flat \
ISAACGYM_CONFIG=isaacgym_config_barbed_flat.yaml \
TASK_NAME=vistac_pih_multiple_vision_onecam_disassembly \
INPUT_TYPE=vision \
ENV_TAG=barbed_flat \
LOG_NAME=bf_vision \
bash scripts/run_local.sh
```

Override any parameter via environment variables: `SEED`, `NUM_DEMOS`, `NUM_EPOCH`, `TASK_NAME`, `DATASET_PATH`, `ISAACGYM_CONFIG`.

---

## 6. Evaluation

Success rates are computed as the average over the final 10 training epochs, each evaluated in 50 environment initializations. Results are averaged over 3 seeds (42, 43, 44), yielding 1500 rollouts per task.

A rollout is deemed successful if the target component is fully extracted and lifted above a predefined height threshold.

---

## Acknowledgments

This codebase is built upon [ManiFeel](https://github.com/purdue-mars/manifeel). We thank the ManiFeel authors for their open-source visuotactile simulation and policy learning framework.

---

## Citation

If you use CONTACT in your research, please cite:

```bibtex
@article{saka2025contact,
  title={CONTACT: CONtact-aware TACTile Learning for Robotic Disassembly},
  author={Saka, Yosuke and Hu, Jyun-Chi and Desai, Adeesh and Zhang, Zhiyuan and Zhang, Bihao and Luu, Quan Khanh and Prince, Md Rakibul Islam and Zheng, Minghui and She, Yu},
  journal={arXiv preprint arXiv:2603.08560},
  year={2025}
}
```
