# Goo Engine Linux Build Wrapper
This project provides a relatively comprehensive, automated toolkit for building, installing, and packaging [Goo Engine](https://github.com/dillongoostudios/goo-engine) (a fork of Blender with an emphasis on NPR) on Linux.

## Prereqs
Before running the scripts, ensure you have the following installed on your Linux distribution (though I'm fairly certain the process should install most of these):
- Git 
- Subversion (svn)
- Python 3
- Wget
- Build Essentials (GCC, Make, CMake)

## Building
```
# Clone this wrapper repository
git clone https://github.com/linuxnoodle/goo-engine-linux-wrapper.git
cd goo-engine-linux-wrapper

# Run the main build script
chmod +x build_goo_engine.sh
./build_goo_engine.sh
```
This will take a stupidly long time. I have a zip of the current `lib/` files [here](https://gofile.io/d/dIOflj), so you don't have to deal with all the 429s if you don't want to. If there's a better way of distributing this, let me know because MAN is this painful.

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
├── diff_ref/               # PATCH SYSTEM: If there are any changes or other breaking features, send a PR!
│   ├── _file_locations.txt # Manifest mapping patch files to target paths.
│   ├── *.from              # Original reference file.
│   ├── *.to                # Fixed reference file.
│   └── *.patch             # Generated diffs.
├── goo-engine/            
├── lib/                   
├── build_linux/           # (Generated) Compiled output (binaries).
└── build_linux_appimage/  # (Generated) Workspace for AppImage creation.
```

## Methodology
I made this in like three hours because I thought it would be easy after trying to build this myself. I didn't make a PR to the goo-engine repo, because these patches are *really* janky. I'll break down the whole process for anyone trying out something similar. A lot of this wouldn't be possible without legendboyAni's explanation [here](https://github.com/dillongoostudios/goo-engine/issues/2#issuecomment-2066268619), though there admittedly is a lot more I needed to do.

What I think the proper installation process is supposed to be is:
- Cloning the repo.
- Installing the requisite packages using `./build_files/build_environment/install_linux_packages.py`.
- Downloading the libraries using `./build_files/utils/make_update.py --use-linux-libraries`.
- Building GooEngine using `make`.

What the actual installation process is:
- Cloning the repo.
- Installing the requisite packages from `./build_files/build_environment/install_linux_packages.py`.
- Patching `./build_files/utils/make_update.py` to retry on timeout, because the servers are seemingly dogshit.
- Taking 81 years to download the libraries using `./build_files/utils/make_update.py --use-linux-libraries`.
- Patching like four files either in `lib/` or `source/` somewhere that causes compilation errors.
- Building GooEngine using `make`.

It honestly wasn't that bad. The problems started when I started trying to automate the build using some scripts. I tried seeing if I could just ignore the `robots.txt` and download the libs through HTTP, with it somehow being even slower than just waiting out the timeout for SVN. I tried just making my own git diffs and using them here, but it was such a tedious process that I just made it modular and slammed the stuff in `diff_ref/`. After all that garbage, I just asked Gemini to make me an installation and AppImage generation script. 

## Current Patches
- `nanovdb/util/GridBuilder.h`: Fixes a template compilation error (isActive -> mValueMask.isOn).
- `pxr/usd/sdf/childrenProxy.h`: Adds missing _Set methods required by newer compilers.
- `lib/linux_x86_64_glibc_228/opencolorio/include/OpenColorIO/OpenColorIO.h`: Literally just adds an include for cstdint.
- `source/creator/buildinfo.c`: Adds missing TIFF variables (TIFFFaxBlackCodes, etc.) to fix linker errors.
- `lib/linux_x86_64_glibc_228/webp`: Renames `webp` to `libwebp` so CMake doesn't yell at me.

## Cleaning
```
chmod +x reset_build.sh
./reset_build.sh
```
