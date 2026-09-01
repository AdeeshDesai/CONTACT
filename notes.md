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
