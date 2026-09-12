#!/bin/bash
set -ex

apt-get update
apt-get install -y --no-install-recommends \
  build-essential git cmake ninja-build meson pkg-config xxd file ca-certificates \
  libsdl2-dev libsdl2-image-dev libsdl2-ttf-dev \
  libgles2-mesa-dev libgl-dev \
  libopenal-dev libphysfs-dev libfluidsynth-dev \
  libtheora-dev libvorbis-dev libpixman-1-dev \
  libuchardet-dev libssl-dev ruby3.1-dev \
  libasound2-dev zlib1g-dev libbz2-dev

# 1. Compilar SDL2_sound (version compatible con SDL2)
git clone --depth 1 --branch git https://github.com/mkxp-z/SDL_sound.git /tmp/sdl_sound
cmake -B /tmp/sdl_sound/build -S /tmp/sdl_sound \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DSDLSOUND_BUILD_STATIC=OFF \
  -DSDLSOUND_BUILD_SHARED=ON
cmake --build /tmp/sdl_sound/build -j$(nproc)
cmake --install /tmp/sdl_sound/build
ldconfig

# 2. Clonar mkxp-z (rama dev con soporte Essentials v21)
git clone --depth 1 --branch dev https://github.com/mkxp-z/mkxp-z.git /tmp/mkxp-z
cd /tmp/mkxp-z

# 3. En Linux glibc, iconv esta integrado en libc (satisfacer comprobacion de meson)
ar cr /usr/lib/libiconv.a
ar cr /usr/lib/libcharset.a
sed -i "s/find_library('iconv')/find_library('iconv', required: false)/g" src/meson.build
sed -i "s/find_library('charset')/find_library('charset', required: false)/g" src/meson.build

# 4. Configurar Meson: GLES + SDL2 dinamica + Ruby 3.1
meson setup build \
  --buildtype=release \
  --default-library=shared \
  -Dgfx_backend=gles \
  -Dmri_version=3.1 \
  -Dshared_fluid=true \
  -Dstatic_executable=false \
  -Dworkdir_current=true \
  -Duse_miniffi=true \
  -Denable-https=true

ninja -C build

# 5. Empaquetar resultado
mkdir -p /workspace/dist/lib
cp build/mkxp-z /workspace/dist/

# 6. Copiar librerias compartidas dependientes
for lib in \
  /usr/lib/aarch64-linux-gnu/libruby-3.1.so* \
  /usr/lib/aarch64-linux-gnu/libphysfs.so* \
  /usr/lib/aarch64-linux-gnu/libopenal.so* \
  /usr/lib/aarch64-linux-gnu/libfluidsynth.so* \
  /usr/lib/aarch64-linux-gnu/libpixman-1.so* \
  /usr/lib/aarch64-linux-gnu/libuchardet.so* \
  /usr/lib/aarch64-linux-gnu/libtheora*.so* \
  /usr/lib/aarch64-linux-gnu/libvorbis*.so* \
  /usr/lib/aarch64-linux-gnu/libogg.so* \
  /usr/lib/libSDL2_sound*.so*; do
  [ -e "$lib" ] && cp -d "$lib" /workspace/dist/lib/ || true
done

cd /workspace/dist/lib
ln -sf libruby-3.1.so.3.1 libruby.so.3.1 || true
ln -sf libruby-3.1.so.3.1 libruby.so || true
