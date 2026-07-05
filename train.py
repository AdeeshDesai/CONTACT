"""
Usage:
Training:
$ python train.py \
  --config-dir=. \
  --config-name=train_diffusion_vision_tactile_workspace.yaml \
  training.seed=42 \
  training.device=cuda:0 \
  hydra.run.dir='data/outputs/${now:%Y.%m.%d}/${now:%H.%M.%S}_${name}_${task_name}'

"""

# IsaacGym links against the conda env's libpython, which the system linker
# cannot find on its own; preloading it removes the need to export
# LD_LIBRARY_PATH=$CONDA_PREFIX/lib.
import ctypes as _ctypes
import os as _os
import sys as _sys
_libpython = _os.path.join(
    _sys.prefix, 'lib',
    f'libpython{_sys.version_info.major}.{_sys.version_info.minor}.so.1.0')
if _os.path.exists(_libpython):
    _ctypes.CDLL(_libpython, mode=_ctypes.RTLD_GLOBAL)

import isaacgym


import os
os.environ["HYDRA_FULL_ERROR"] = "1"


import sys
# use line-buffering for both stdout and stderr
sys.stdout = open(sys.stdout.fileno(), mode='w', buffering=1)
sys.stderr = open(sys.stderr.fileno(), mode='w', buffering=1)

import hydra
from omegaconf import OmegaConf
import pathlib
from diffusion_policy.workspace.base_workspace import BaseWorkspace

# allows arbitrary python code execution in configs using the ${eval:''} resolver
OmegaConf.register_new_resolver("eval", eval, replace=True)

@hydra.main(
    version_base=None,
    config_path=str(pathlib.Path(__file__).parent.joinpath(
        './contact','config'))
)
def main(cfg: OmegaConf):
    # resolve immediately so all the ${now:} resolvers
    # will use the same time.
    OmegaConf.resolve(cfg)
    cls = hydra.utils.get_class(cfg._target_)
    workspace: BaseWorkspace = cls(cfg)
    workspace.run()

if __name__ == "__main__":
    main()