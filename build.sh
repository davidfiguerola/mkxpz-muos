#!/bin/bash
set -ex

apt-get update
apt-get install -y --no-install-recommends \
  build-essential git cmake ninja-build meson pkg-config xxd file ca-certificates \
  libsdl2-dev libsdl2-image-dev libsdl2-ttf-dev \
  libgles2-mesa-dev libgl-dev \
  libglib2.0-dev libgmp-dev libasound2-dev \
  libphysfs-dev libtheora-dev libvorbis-dev libpixman-1-dev \
  libuchardet-dev libssl-dev ruby3.1-dev \
  zlib1g-dev libbz2-dev

# 1. Compilar SDL2_sound
git clone --depth 1 --branch git https://github.com/mkxp-z/SDL_sound.git /tmp/sdl_sound
cmake -B /tmp/sdl_sound/build -S /tmp/sdl_sound \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DSDLSOUND_BUILD_STATIC=OFF \
  -DSDLSOUND_BUILD_SHARED=ON
cmake --build /tmp/sdl_sound/build
cmake --install /tmp/sdl_sound/build

# 2. Compilar OpenAL-Soft limpio (SOLO ALSA nativo, sin Jack, Pulse, Sndio ni dependencias de escritorio)
git clone --depth 1 https://github.com/kcat/openal-soft.git /tmp/openal-soft
cmake -B /tmp/openal-soft/build -S /tmp/openal-soft \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DLIBTYPE=SHARED \
  -DALSOFT_BACKEND_ALSA=ON \
  -DALSOFT_BACKEND_PULSEAUDIO=OFF \
  -DALSOFT_BACKEND_JACK=OFF \
  -DALSOFT_BACKEND_PORTAUDIO=OFF \
  -DALSOFT_BACKEND_SNDIO=OFF \
  -DALSOFT_BACKEND_OSS=OFF \
  -DALSOFT_EXAMPLES=OFF \
  -DALSOFT_UTILS=OFF
cmake --build /tmp/openal-soft/build
cmake --install /tmp/openal-soft/build

# 3. Compilar FluidSynth limpio (SOLO ALSA y GLib, sin Jack, Pulse ni Readline)
git clone --depth 1 --branch v2.3.4 https://github.com/FluidSynth/fluidsynth.git /tmp/fluidsynth
cmake -B /tmp/fluidsynth/build -S /tmp/fluidsynth \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DBUILD_SHARED_LIBS=ON \
  -Denable-alsa=ON \
  -Denable-pulseaudio=OFF \
  -Denable-jack=OFF \
  -Denable-dbus=OFF \
  -Denable-readline=OFF \
  -Denable-network=OFF \
  -Denable-sdl2=OFF
cmake --build /tmp/fluidsynth/build
cmake --install /tmp/fluidsynth/build

ldconfig

# 4. Clonar mkxp-z (rama dev con soporte Essentials v21)
git clone --depth 1 --branch dev https://github.com/mkxp-z/mkxp-z.git /tmp/mkxp-z
cd /tmp/mkxp-z

# 5. Parches de compatibilidad
ar cr /usr/lib/libiconv.a
ar cr /usr/lib/libcharset.a
sed -i "s/find_library('iconv')/find_library('iconv', required: false)/g" src/meson.build
sed -i "s/find_library('charset')/find_library('charset', required: false)/g" src/meson.build
sed -i "s/theora = dependency('theora', static: build_static)/theora = [dependency('theora', static: build_static), dependency('theoradec', static: build_static)]/g" src/meson.build

# 6. Configurar Meson: GLES + SDL2 dinamica + Ruby 3.1
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

# 7. Empaquetar resultado limpio
mkdir -p /workspace/dist/lib
cp build/mkxp-z.aarch64 /workspace/dist/mkxp-z
chmod +x /workspace/dist/mkxp-z

# 8. Copiar unicamente las librerias nativas de Debian Bookworm requeridas
for lib in \
  /usr/lib/libopenal.so* \
  /usr/lib/libfluidsynth.so* \
  /usr/lib/libSDL2_sound*.so* \
  /usr/lib/aarch64-linux-gnu/libruby-3.1.so* \
  /usr/lib/aarch64-linux-gnu/libphysfs.so* \
  /usr/lib/aarch64-linux-gnu/libpixman-1.so* \
  /usr/lib/aarch64-linux-gnu/libuchardet.so* \
  /usr/lib/aarch64-linux-gnu/libtheora*.so* \
  /usr/lib/aarch64-linux-gnu/libvorbis*.so* \
  /usr/lib/aarch64-linux-gnu/libogg.so* \
  /usr/lib/aarch64-linux-gnu/libglib-2.0.so* \
  /usr/lib/aarch64-linux-gnu/libgmp.so* \
  /usr/lib/aarch64-linux-gnu/libgomp.so* \
  /usr/lib/aarch64-linux-gnu/libcrypt.so* \
  /usr/lib/aarch64-linux-gnu/libssl.so* \
  /usr/lib/aarch64-linux-gnu/libcrypto.so*; do
  [ -e "$lib" ] && cp -d "$lib" /workspace/dist/lib/ || true
done

cd /workspace/dist/lib
ln -sf libruby-3.1.so.3.1 libruby.so.3.1 || true
ln -sf libruby-3.1.so.3.1 libruby.so || true
