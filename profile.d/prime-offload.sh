# NVIDIA PRIME Offload
export __NV_PRIME_RENDER_OFFLOAD=1
export __GLX_VENDOR_LIBRARY_NAME=nvidia
export __VK_LAYER_NV_optimus=NVIDIA_only

# Intel iGPU offload for compute
export MESA_LOADER_DRIVER_OVERRIDE=i965
