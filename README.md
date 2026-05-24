# Goo Engine Linux Build Wrapper (v4.3)
This project provides a relatively comprehensive, automated toolkit for building, installing, and packaging [Goo Engine](https://github.com/dillongoostudios/goo-engine) (a fork of Blender with an emphasis on NPR) on Linux.

This branch targets `goo-engine-v4.3-release` (Blender 4.3.2).

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
git clone -b v4.3-release https://github.com/linuxnoodle/goo-engine-linux-wrapper.git
cd goo-engine-linux-wrapper

# Run the main build script
chmod +x build_goo_engine.sh
./build_goo_engine.sh
```

The v4.3 branch downloads its libraries through git LFS submodules from Blender's own repos, so you don't need the separate `lib/` submodule or SVN anymore. It'll still take a while though.

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
The v4.3 branch changed things up from the older goo-engine builds. Libraries are now distributed through git LFS submodules instead of SVN, and `make_update.py` doesn't need to be patched for rate limiting anymore. The build process is honestly a lot cleaner now.

What the installation process looks like:
- Cloning goo-engine and checking out the v4.3 branch.
- Installing the requisite packages from `./build_files/build_environment/install_linux_packages.py`.
- Downloading the libraries using `./build_files/utils/make_update.py --use-linux-libraries`.
- Patching a handful of files in `lib/` and `source/` that cause compilation errors.
- Copying `libsycl.so` into the build output because it doesn't get bundled by default and the binary won't launch without it.
- Building GooEngine using `make`.

## Current Patches
- `nanovdb/util/GridBuilder.h`: Fixes a template compilation error (isActive -> mValueMask.isOn). OpenVDB 11.0 still has this.
- `pxr/usd/sdf/childrenProxy.h`: Adds missing _Set methods required by newer compilers. USD 24.05 still has this.
- `opencolorio/include/OpenColorIO/OpenColorIO.h`: Literally just adds an include for cstdint. OCIO 2.3.2 still has this.
- `source/creator/buildinfo.c`: Adds missing TIFF variables (TIFFFaxBlackCodes, etc.) to fix linker errors.

## Known Issues & Workarounds

### startup.blend LFS pointer
The goo-engine repo has exceeded its GitHub LFS budget, so `release/datafiles/startup.blend` is an LFS pointer instead of a real blend file. If you have Blender installed system-wide, the build script will detect this and generate a working replacement automatically. If not, you'll need to manually provide a valid `startup.blend` from an official Blender release.

### Runtime Fix
The build compiles fine but the binary won't launch because `libsycl.so.7` isn't copied to the output directory by default. The build script handles this automatically by copying it from `lib/linux_x64/dpcpp/lib/` into `build_linux/bin/lib/`. If you're building manually, you'll need to do this yourself.

## Cleaning
```
chmod +x reset_build.sh
./reset_build.sh
```
