FROM ubuntu:22.04 as builder

ENV DEBIAN_FRONTEND="noninteractive" TZ="Europe/London"

ARG TARGETPLATFORM
ARG docker_ip
ARG user_pass

RUN ln -s /usr/bin/dpkg-split /usr/sbin/dpkg-split && \
    ln -s /usr/bin/dpkg-deb /usr/sbin/dpkg-deb && \
    ln -s /bin/rm /usr/sbin/rm && \
    ln -s /bin/tar /usr/sbin/tar && \
    ln -s /bin/as /usr/sbin/as

RUN apt-get update -y && \
    apt install -y python3 python3-dev python3-pip build-essential cmake git wget sshpass


RUN git config --global http.sslVerify "false"

RUN pip install conan==1.60.1

RUN conan profile new --detect default && \
    conan profile update settings.compiler.libcxx=libstdc++11 default

WORKDIR /usr/src/ustore-deps
COPY . /usr/src/ustore-deps

RUN git clone https://github.com/unum-cloud/ustore.git && \
    cd ustore/ && git checkout main-dev && git submodule update --init --recursive

# Disable ustore-deps build
RUN sed -i 's/^\(.*\)cmake = CMake(self)/# \1cmake = CMake(self)/; s/^\(.*\)cmake.configure()/# \1cmake.configure()/; s/^\(.*\)cmake.build()/# \1cmake.build()\n       pass/' ./ustore/conanfile.py

RUN if [ "$TARGETPLATFORM" = "linux/amd64" ]; then \
        mv conanfile.py ./ustore/ && \
        conan create ./ustore unum/x86_linux --build=missing && \
        cd ~/.conan && tar -czvf ustore_deps_x86_linux.tar.gz data/ && \
        sshpass -p "$user_pass" scp -o StrictHostKeyChecking=no ustore_deps_x86_linux.tar.gz runner@"$docker_ip":/home/runner/work/ustore-deps-test/ustore-deps-test/; \
    elif [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
        mv conanfile.py ./ustore/ && \
        conan create ./ustore unum/arm_linux --build=missing && \
        cd ~/.conan && tar -czvf ustore_deps_arm_linux.tar.gz data/ && \
        sshpass -p "$user_pass" scp -o StrictHostKeyChecking=no ustore_deps_arm_linux.tar.gz runner@"$docker_ip":/home/runner/work/ustore-deps-test/ustore-deps-test/; \
    fi
