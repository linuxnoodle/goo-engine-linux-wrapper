# Goo Engine Linux Build Wrapper (v4.4)
This project provides a relatively comprehensive, automated toolkit for building, installing, and packaging [Goo Engine](https://github.com/dillongoostudios/goo-engine) (a fork of Blender with an emphasis on NPR) on Linux.

This branch targets `goo-engine-v4.4-release` (Blender 4.4.3).

## Prereqs
Before running the scripts, ensure you have the following installed on your Linux distribution (though the process should install most of these):
- Git
- Git LFS
- Python 3
- Wget
- Build Essentials (GCC, Make, CMake)

## Building
```
# Clone this wrapper repository
git clone -b v4.4-release https://github.com/linuxnoodle/goo-engine-linux-wrapper.git
cd goo-engine-linux-wrapper

# Run the main build script
chmod +x build_goo_engine.sh
./build_goo_engine.sh
```

The v4.4 branch downloads its libraries through git LFS submodules from Blender's own repos, so you don't need the separate `lib/` submodule or SVN anymore.

## Installing
```
chmod +x install_goo_engine.sh
./install_goo_engine.sh
```
This will install the .desktop file, and symlink it to `.local/bin`. The project needs to be succesfully compiled for this to run.

## Creating an AppImage
```
chmod +x build_appimage.sh
./build_appimage.sh
```
This will build an AppImage for this project. The project also needs to be succesfully compiled for this to run.

## General Project Structure
```
├── build_goo_engine.sh    
├── build_appimage.sh      
├── install_goo_engine.sh  
├── generate_patches.sh
├── diff_ref/               # PATCH SYSTEM
│   ├── _file_locations.txt # Manifest mapping patch files to target paths.
│   ├── *.from              # Original reference file.
│   ├── *.to                # Fixed reference file.
│   └── *.patch             # Generated diffs.
├── goo-engine/            
├── build_linux/           # (Generated) Compiled output (binaries).
└── build_linux_appimage/  # (Generated) Workspace for AppImage creation.
```

## Methodology
v4.4 uses the same git LFS library setup as v4.3. The good news is that upstream has fixed a bunch of the compilation issues that needed patching in older versions. Only two patches are needed now.

What the installation process looks like:
- Cloning goo-engine and checking out the v4.4 branch.
- Installing the requisite packages from `./build_files/build_environment/install_linux_packages.py`.
- Downloading the libraries using `./build_files/utils/make_update.py --use-linux-libraries`.
- Patching two files that still cause compilation errors.
- Copying `libsycl.so` and `libur_loader.so` into the build output because they don't get bundled by default.
- Building GooEngine using `make`.

## Current Patches
- `pxr/usd/sdf/childrenProxy.h`: Adds missing _Set methods required by newer compilers. USD 25.02 still has this.
- `source/creator/buildinfo.c`: Adds missing TIFF variables (TIFFFaxBlackCodes, etc.) to fix linker errors.

The nanovdb GridBuilder.h and OpenColorIO patches from older versions are no longer needed. OpenVDB 12.0 removed the broken `isActive` call and OCIO 2.4.1 finally includes `<cstdint>`.

## Known Issues & Workarounds

### startup.blend LFS pointer
The goo-engine repo has exceeded its GitHub LFS budget, so `release/datafiles/startup.blend` is an LFS pointer instead of a real blend file. If you have Blender installed system-wide, the build script will detect this and generate a working replacement automatically. If not, you'll need to manually provide a valid `startup.blend` from an official Blender release.

### Shader compile error (v4.4 only)
`effect_minmaxz_frag.glsl` uses the deprecated `gl_FragColor` which is invalid in GLSL 330+ core. The build script patches this to `fragColor` to match the shader info declaration. This is a goo-engine bug not present in v4.3.

### Runtime Fix
Same situation as v4.3 - the build compiles fine but the binary won't launch without `libsycl.so` and `libur_loader.so` in the output directory. The build script handles this automatically. v4.4 uses `libsycl.so.8` (v4.3 used `.7`) and also needs `libur_loader.so.0`.

## Cleaning
```
chmod +x reset_build.sh
./reset_build.sh
```

---

## v5.2-release branch (Goo Engine on Blender 5.2 / EEVEE-Next)

This branch builds the unofficial
[NaMgAl-Studio/goo-engine-5.2.0](https://github.com/NaMgAl-Studio/goo-engine-5.2.0)
port: Goo Engine's NPR feature set re-implemented on Blender 5.2 /
EEVEE-Next (BSL shader pipeline).

```
git clone -b v5.2-release https://github.com/linuxnoodle/goo-engine-linux-wrapper.git
cd goo-engine-linux-wrapper
chmod +x build_goo_engine_52.sh
./build_goo_engine_52.sh     # builds with Cycles HIP (ROCm) support
./install_goo_engine_52.sh   # installs to ~/.local/share/goo-engine-52 (isolated config)
```

Highlights (full detail in [DIFFERENCES_52.md](DIFFERENCES_52.md)):

- Dedicated **"Goo Engine"** render-engine entry (`BLENDER_GOO_ENGINE`) plus
  UI-panel compatibility patch — the dropdown and settings match goo-engine 4.4.
- **Black-material fix** for legacy Goo shader packs containing structural
  link cycles: the 5.2
  shader inliner aborted on structural link cycles that Blender flags
  `NODE_LINK_VALID=0` (invalid links counted as "available"), producing
  empty materials. Cycle checks + traversal now ignore invalid links, like
  legacy EEVEE did.
- `WITH_GPU_SHADER_CPP_COMPILATION=OFF` (GCC 16 linting error), HIP kernel
  build (`CYCLES_HIP_BINARIES_ARCH=gfx1030`), SYCL runtime-libs copy.
- Launcher isolates user resources (`BLENDER_USER_RESOURCES`) so the 5.2
  build never collides with stock Blender 5.2 config.

The v4.4 branch (original goo-engine) remains available and is still the
production-NPR recommendation per the port's own README.

> **EXPERIMENTAL — AI-GENERATED.** This branch is experimental, generated with
> AI assistance, and is **derived from
> [NaMgAl-Studio/goo-engine-5.2.0](https://github.com/NaMgAl-Studio/goo-engine-5.2.0)**
> (an unofficial port of Goo Engine to Blender 5.2 / EEVEE-Next), which in turn
> derives from [dillongoostudios/goo-engine](https://github.com/dillongoostudios/goo-engine)
> and Blender. Use at your own risk; for production NPR work prefer the
> original Goo Engine (v4.4 branch of this wrapper) or Blender itself.

