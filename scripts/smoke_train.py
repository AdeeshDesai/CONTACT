#!/usr/bin/env python3

import copy
import pathlib

import hydra
import torch
from omegaconf import OmegaConf

from contact.workspace.train_diffusion_unet_image_workspace import (
    get_scheduler,
    resolve_device,
)
from diffusion_policy.common.normalize_util import get_image_range_normalizer
from diffusion_policy.model.common.normalizer import (
    LinearNormalizer,
    SingleFieldLinearNormalizer,
)
from diffusion_policy.model.diffusion.ema_model import EMAModel


def make_normalizer(shape_meta):
    normalizer = LinearNormalizer()
    for key, metadata in shape_meta["obs"].items():
        if metadata.get("type", "low_dim") == "rgb":
            normalizer[key] = get_image_range_normalizer()
        else:
            normalizer[key] = SingleFieldLinearNormalizer.create_identity()
    normalizer["action"] = SingleFieldLinearNormalizer.create_identity()
    return normalizer


def make_batch(shape_meta, horizon, n_obs_steps, device):
    obs = {}
    for key, metadata in shape_meta["obs"].items():
        shape = tuple(metadata["shape"])
        obs[key] = torch.rand(
            (1, n_obs_steps, *shape),
            dtype=torch.float32,
            device=device,
        )
    action_shape = tuple(shape_meta["action"]["shape"])
    action = torch.rand(
        (1, horizon, *action_shape),
        dtype=torch.float32,
        device=device,
    )
    return {"obs": obs, "action": action}


def main():
    OmegaConf.register_new_resolver("eval", eval, replace=True)
    config_dir = pathlib.Path(__file__).resolve().parents[1] / "contact" / "config"
    with hydra.initialize_config_dir(
        config_dir=str(config_dir),
        version_base=None,
    ):
        cfg = hydra.compose(
            config_name="train_diffusion_workspace_disassembly.yaml",
            overrides=["task=vision_disassembly"],
        )

    device = resolve_device(cfg.training.device)

    torch.manual_seed(cfg.training.seed)
    model = hydra.utils.instantiate(cfg.policy)
    model.set_normalizer(make_normalizer(cfg.shape_meta))
    model.to(device)
    ema_model = copy.deepcopy(model)
    ema: EMAModel = hydra.utils.instantiate(cfg.ema, model=ema_model)
    optimizer = hydra.utils.instantiate(cfg.optimizer, params=model.parameters())
    lr_scheduler = get_scheduler(
        cfg.training.lr_scheduler,
        optimizer=optimizer,
        num_warmup_steps=cfg.training.lr_warmup_steps,
        num_training_steps=4,
    )
    batch = make_batch(
        cfg.shape_meta,
        horizon=cfg.horizon,
        n_obs_steps=cfg.n_obs_steps,
        device=device,
    )

    optimizer.zero_grad(set_to_none=True)
    loss = model.compute_loss(batch)
    if not torch.isfinite(loss):
        raise RuntimeError(f"non-finite loss: {loss.item()}")
    loss.backward()
    optimizer.step()
    lr_scheduler.step()
    ema.step(model)
    if device.type == "cuda":
        torch.cuda.synchronize()

    device_label = (
        torch.cuda.get_device_name(device)
        if device.type == "cuda"
        else str(device))
    print(f"device={device_label}")
    print(f"loss={loss.item():.8f}")
    print(f"lr={lr_scheduler.get_last_lr()[0]:.8g}")
    print(f"ema_step={ema.optimization_step}")


if __name__ == "__main__":
    main()
