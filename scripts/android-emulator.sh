#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export ANDROID_AVD_HOME="${ANDROID_AVD_HOME:-$project_root/.android/avd}"
export ANDROID_USER_HOME="${ANDROID_USER_HOME:-$project_root/.android}"

if ! command -v emulator >/dev/null; then
  echo "Run this launcher inside devenv shell (campus-emulator)." >&2
  exit 1
fi

# devenv's general library path can mix incompatible libc versions into the
# emulator. Keep driver libraries scoped to this process instead.
unset LD_LIBRARY_PATH

# Nix cannot discover Ubuntu's proprietary NVIDIA driver automatically. Include
# its GL libraries and the XCB libraries it dlopens (notably GLX and DRI3).
# Do not add all of /usr/lib: that would also replace Nix's libc and C++ runtime.
host_libs=/usr/lib/x86_64-linux-gnu
if [[ -f /proc/driver/nvidia/version && -e "$host_libs/libGLX_nvidia.so.0" ]]; then
  driver_dir="$project_root/.devenv/emulator-host-gpu"
  mkdir -p -- "$driver_dir"
  shopt -s nullglob
  for library in \
    "$host_libs"/libGL.so* "$host_libs"/libGLX.so* \
    "$host_libs"/libGLdispatch.so* "$host_libs"/libEGL.so* \
    "$host_libs"/libGLESv2.so* \
    "$host_libs"/libGLX_nvidia.so* "$host_libs"/libEGL_nvidia.so* \
    "$host_libs"/libnvidia-{glcore,eglcore,glsi,gpucomp,allocator,tls}.so* \
    "$host_libs"/libX{11,11-xcb,ext,au,dmcp}.so* \
    "$host_libs"/libxcb.so* \
    "$host_libs"/libxcb-{glx,randr,dri3,present,sync}.so* \
    "$host_libs"/libxshmfence.so*; do
    ln -sfn -- "$library" "$driver_dir/${library##*/}"
  done
  export LD_LIBRARY_PATH="$driver_dir"
  export __GLX_VENDOR_LIBRARY_NAME=nvidia
  if [[ -f /usr/share/glvnd/egl_vendor.d/10_nvidia.json ]]; then
    export __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/10_nvidia.json
  fi
fi

# The bundled Qt has X11 support, including through XWayland.
export QT_QPA_PLATFORM=xcb

# Keep the app's normal OpenGL backend. Vulkan and Quick Boot introduced
# separate failures during map testing; cold boots preserve installed app data.
exec emulator -avd "${CAMPUS_AVD:-campus_api36}" \
  -gpu host -feature -Vulkan -no-snapshot -no-boot-anim "$@"
