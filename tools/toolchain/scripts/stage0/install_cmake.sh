#!/bin/bash -e

# TODO: Review and if possible fix shellcheck errors.
# shellcheck disable=SC1003,SC1035,SC1083,SC1090
# shellcheck disable=SC2001,SC2002,SC2005,SC2016,SC2091,SC2034,SC2046,SC2086,SC2089,SC2090
# shellcheck disable=SC2124,SC2129,SC2144,SC2153,SC2154,SC2155,SC2163,SC2164,SC2166
# shellcheck disable=SC2235,SC2237

[ "${BASH_SOURCE[0]}" ] && SCRIPT_NAME="${BASH_SOURCE[0]}" || SCRIPT_NAME=$0
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_NAME")/.." && pwd -P)"

source "${SCRIPT_DIR}"/common_vars.sh
source "${SCRIPT_DIR}"/tool_kit.sh
source "${SCRIPT_DIR}"/signal_trap.sh
source "${INSTALLDIR}"/toolchain.conf
source "${INSTALLDIR}"/toolchain.env

[ -f "${BUILDDIR}/setup_cmake" ] && rm "${BUILDDIR}/setup_cmake"

! [ -d "${BUILDDIR}" ] && mkdir -p "${BUILDDIR}"
cd "${BUILDDIR}"

case "${with_cmake}" in
  __INSTALL__)
    echo "==================== Installing CMake ===================="
    cmake_ver="3.22.1"
    if [ "${OPENBLAS_ARCH}" = "arm64" ]; then
      cmake_arch="Linux-aarch64"
      cmake_sha256="ff886c6c16be867229a6c1fe4bc963ff77ae24187d5a8d64ef72a06f84c1a25c"
    elif [ "${OPENBLAS_ARCH}" = "x86_64" ]; then
      cmake_arch="Linux-x86_64"
      cmake_sha256="808a712bcb039fd71f6960dca82a9befb977d8bdb074718218cf7646fd08bb7a"
    else
      report_error ${LINENO} \
        "cmake installation for ARCH=${ARCH} is not supported. You can try to use the system installation using the flag --with-cmake=system instead."
      exit 1
    fi
    pkg_install_dir="${INSTALLDIR}/cmake-${cmake_ver}"
    install_lock_file="$pkg_install_dir/install_successful"
    if verify_checksums "${install_lock_file}"; then
      echo "cmake-${cmake_ver} is already installed, skipping it."
    else
      if [ -f cmake-${cmake_ver}-${cmake_arch}.sh ]; then
        echo "cmake-${cmake_ver}-${cmake_arch}.sh is found"
      else
        download_pkg ${DOWNLOADER_FLAGS} ${cmake_sha256} \
          https://github.com/Kitware/CMake/releases/download/v${cmake_ver}/cmake-${cmake_ver}-${cmake_arch}.sh
      fi
      echo "Installing from scratch into ${pkg_install_dir}"
      mkdir -p ${pkg_install_dir}
      /bin/sh cmake-${cmake_ver}-${cmake_arch}.sh --prefix=${pkg_install_dir} --skip-license > install.log 2>&1 || tail -n ${LOG_LINES} install.log
      write_checksums "${install_lock_file}" "${SCRIPT_DIR}/stage0/$(basename ${SCRIPT_NAME})"
    fi
    ;;
  __SYSTEM__)
    echo "==================== Finding CMake from system paths ===================="
    check_command cmake "cmake"
    ;;
  __DONTUSE__)
    # Nothing to do
    ;;
  *)
    echo "==================== Linking CMake to user paths ===================="
    pkg_install_dir="$with_cmake"
    check_dir "${with_cmake}/bin"
    ;;
esac
if [ "${with_cmake}" != "__DONTUSE__" ]; then
  if [ "${with_cmake}" != "__SYSTEM__" ]; then
    cat << EOF > "${BUILDDIR}/setup_cmake"
prepend_path PATH "${pkg_install_dir}/bin"
EOF
    cat "${BUILDDIR}/setup_cmake" >> $SETUPFILE
  fi
fi

load "${BUILDDIR}/setup_cmake"
write_toolchain_env "${INSTALLDIR}"

cd "${ROOTDIR}"
report_timing "cmake"
