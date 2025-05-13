#! /bin/bash

export VERSION=6.1
SWIFT_VERSION=swift-${VERSION}-RELEASE ./fetch-sources.sh

export SWIFT_VERSION=${VERSION}
export SWIFT_TAG=swift-${SWIFT_VERSION}-RELEASE
export SWIFT_WORKSPACE_CACHE=swift-workspace
export DOCKER_TAG=xtremekforever/swift-builder:${SWIFT_VERSION}
export DISTRIBUTION=ubuntu-jammy
export SWIFT_TARGET_ARCH=armv7

./build-sysroot.sh $(echo ${DISTRIBUTION/-/ }) sysroot-${DISTRIBUTION}

tar -czf sysroot-${DISTRIBUTION}.tar.gz sysroot-${DISTRIBUTION}

docker run -d --name swift-${SWIFT_TARGET_ARCH}-builder -v $HOME:$HOME \
  -e SWIFT_VERSION=${SWIFT_VERSION} \
  -e STAGING_DIR=$(pwd)/sysroot-${DISTRIBUTION} \
  -e INSTALL_TAR=$(pwd)/swift-${SWIFT_VERSION}-RELEASE-${DISTRIBUTION}-${SWIFT_TARGET_ARCH}-install.tar.gz \
  -e SWIFT_TARGET_ARCH=${SWIFT_TARGET_ARCH} \
  xtremekforever/swift-builder:${SWIFT_VERSION} \
  tail -f /dev/null

docker exec swift-${SWIFT_TARGET_ARCH}-builder /bin/bash -c "apt remove -y libcurl4-openssl-dev"
docker exec --user ${USER} --workdir $(pwd) swift-${SWIFT_TARGET_ARCH}-builder ./build.sh

INSTALLABLE_SDK_PACKAGE=$(pwd)/${SWIFT_TAG}-${DISTRIBUTION}-${SWIFT_TARGET_ARCH}-sdk.tar.gz \
  SYSROOT=$(pwd)/sysroot-${DISTRIBUTION} \
  TARGET_ARCH=${SWIFT_TARGET_ARCH} \
  ./build-linux-cross-sdk.sh $SWIFT_TAG $DISTRIBUTION

docker run --rm --user ${USER} --workdir $(pwd) -v $HOME:$HOME -v $(pwd)/artifacts:/opt \
    xtremekforever/swift-builder:${SWIFT_VERSION} \
    swift build -c release \
        --package-path swift-hello \
        --destination /opt/${SWIFT_TAG}-${DISTRIBUTION}-${SWIFT_TARGET_ARCH}/${DISTRIBUTION}.json \
        -Xswiftc -cxx-interoperability-mode=default \
        -Xswiftc -enable-testing
cp $(pwd)/swift-hello/.build/release/swift-hello $(pwd)/artifacts/swift-hello

docker run --rm --user ${USER} --workdir $(pwd) -v $HOME:$HOME -v $(pwd)/artifacts:/opt \
    xtremekforever/swift-builder:${SWIFT_VERSION} \
    swift build -c release \
        --package-path swift-hello \
        --destination /opt/${SWIFT_TAG}-${DISTRIBUTION}-${SWIFT_TARGET_ARCH}/${DISTRIBUTION}-static.json \
        -Xswiftc -cxx-interoperability-mode=default \
        --static-swift-stdlib
cp $(pwd)/swift-hello/.build/release/swift-hello $(pwd)/artifacts/swift-hello-static