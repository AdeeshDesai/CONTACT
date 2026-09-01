# AMD / ROCm Bring-up Notes

This file records working environment commands for the AMD path. It is the
source material for the future Ryzers Dockerfile.

## S0: gfx1151 ROCm baseline

Host:

- GPU: AMD Radeon 8060S Graphics (Strix Halo)
- Kernel driver: `amdgpu`
- Device nodes: `/dev/kfd`, `/dev/dri/card0`, `/dev/dri/renderD128`
- Host supplemental group IDs: `video=44`, `render=990`

Pull the pinned image:

```bash
docker pull rocm/pytorch:rocm7.14_ubuntu24.04_py3.12_pytorch_release_2.12.0
```

Start a persistent development container:

```bash
docker run -d \
  --name contact-rocm714 \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add 44 \
  --group-add 990 \
  --security-opt seccomp=unconfined \
  --shm-size=16g \
  -v /home/victor/Desktop/CONTACT-amd:/workspace/CONTACT \
  -w /workspace/CONTACT \
  rocm/pytorch:rocm7.14_ubuntu24.04_py3.12_pytorch_release_2.12.0 \
  sleep infinity
```

Group names cannot be used with this image because its `/etc/group` does not
contain `render`; use the numeric host group IDs above.

Verify PyTorch, HIP, the GPU architecture, and a GPU kernel:

```bash
docker exec contact-rocm714 python -c "import torch; p=torch.cuda.get_device_properties(0) if torch.cuda.is_available() else None; print('torch=', torch.__version__); print('hip=', torch.version.hip); print('available=', torch.cuda.is_available()); print('count=', torch.cuda.device_count()); print('device=', torch.cuda.get_device_name(0) if p else None); print('arch=', getattr(p, 'gcnArchName', None) if p else None); x=torch.randn((1024,1024), device=torch.device('cuda')); y=x@x; torch.cuda.synchronize(); print('kernel_sum=', y.sum().item())"
```

Verified output:

```text
torch= 2.12.0+rocm7.14.0
hip= 7.14.60850
available= True
count= 1
device= AMD Radeon 8060S Graphics
arch= gfx1151
```

No alternate wheel, TheRock nightly, or `HSA_OVERRIDE_GFX_VERSION` was needed.

## S1: dependencies and one policy training step

Fetch the tested Diffusion Policy revision:

```bash
mkdir -p thirdparty
git clone https://github.com/real-stanford/diffusion_policy.git \
  thirdparty/diffusion_policy
git -C thirdparty/diffusion_policy checkout \
  5ba07ac6661db573af695b419a7947ecb704690f
```

Install the AMD-only requirements:

```bash
docker exec contact-rocm714 \
  python -m pip install -r requirements-amd.txt
```

The upstream repositories use namespace-style source trees without top-level
`__init__.py` files. Use setuptools compatible editable mode so both source
roots are placed on `sys.path`:

```bash
docker exec contact-rocm714 python -m pip install \
  --no-deps \
  --force-reinstall \
  --config-settings editable_mode=compat \
  -e thirdparty/diffusion_policy \
  -e .
```

Verified core versions:

```text
diffusers=0.40.0
numpy=2.5.1
numba=0.67.0
zarr=2.18.7
opencv=5.0.0
```

Run the synthetic one-step policy smoke test:

```bash
docker exec -e USE_SIM=0 contact-rocm714 \
  python scripts/smoke_train_amd.py
```

Verified output:

```text
device=AMD Radeon 8060S Graphics
arch=gfx1151
loss=1.26865768
lr=1.6e-07
ema_step=1
```

The generic base image does not contain the optional
`gfx1151_20.HIP.fdb.txt` MIOpen Find-DB file, so MIOpen emits a warning and
performs runtime kernel selection. The full ResNet + diffusion UNet forward,
backward, optimizer, scheduler, and EMA step completed successfully in 13.6
seconds on the first run and 5.3 seconds after kernel caching. No environment
workaround was applied.

Check the resolved environment:

```bash
docker exec contact-rocm714 python -m pip check
```

Result: `No broken requirements found.`

## S2: barbed_flat dataset and offline evaluation

Install the dataset download and extraction tools:

```bash
docker exec contact-rocm714 python -m pip install gdown
docker exec contact-rocm714 bash -lc \
  "apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends unzip"
```

The repository download script currently asks Google Drive for the entire
folder even when one task is requested:

```bash
docker exec contact-rocm714 bash scripts/download_data.sh barbed_flat
```

The completed `barbed_flat.zip` was retained and the downloads of the other
tasks were stopped and removed. The extracted dataset is 413 MB.

Verified dataset:

```text
episodes=50
dataset_len=3222
front=(2, 3, 256, 256)
wrist=(2, 3, 256, 256)
tactile_force_field_right=(2, 3, 10, 14)
state=(2, 7)
action=(16, 7)
```

Run one TacFF train step, one validation step, and a 10-step diffusion sample:

```bash
docker exec \
  -e USE_SIM=0 \
  -e WANDB_MODE=disabled \
  contact-rocm714 \
  python train.py \
  --config-name=train_diffusion_workspace_disassembly.yaml \
  task=visff_disassembly \
  dataset_path=data/barbed_flat \
  training.enable_rollout=false \
  training.device=auto \
  training.seed=42 \
  training.resume=false \
  training.num_epochs=1 \
  training.max_train_steps=1 \
  training.max_val_steps=1 \
  training.val_every=1 \
  training.sample_every=1 \
  training.checkpoint_every=10000 \
  checkpoint.save_last_ckpt=false \
  logging.mode=disabled \
  dataloader.batch_size=1 \
  dataloader.num_workers=0 \
  val_dataloader.batch_size=1 \
  val_dataloader.num_workers=0 \
  policy.num_inference_steps=10 \
  hydra.run.dir=data/outputs/s2-one-step
```

Verified metrics:

```text
train_loss=0.9548164010047913
val_loss=0.9805130958557129
train_action_mse_error=0.6669871807098389
```

For the three-epoch short run, change `training.num_epochs=3` and use
`hydra.run.dir=data/outputs/s2-short-run`. Each epoch was limited to one train
and one validation batch.

```text
epoch  train_loss          val_loss            train_action_mse_error
0      0.9548164010047913  0.9805130958557129  0.6669871807098389
1      1.1557873487472534  1.0857679843902588  0.6440054178237915
2      1.0130190849304200  1.1079219579696655  0.6709109544754028
```

Repeating the three-epoch command with the same seed produced a byte-identical
metrics log:

```text
cbda52ab6e5352dde1886069a5a1ab27745f62c0ffdc890de5ae4f9c9fc83a29
```

The container does not contain IsaacGym. Both runs exited successfully, which
verifies that `training.enable_rollout=false` did not import or instantiate
the NVIDIA runner. No NVIDIA reference curve was available, so these metrics
are an AMD smoke-test baseline only, not a cross-hardware equivalence claim.
