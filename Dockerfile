FROM debian:9.8
LABEL maintainer="e.demirel@qmul.qc.uk"

COPY . /ALTA

# Installing libraries
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        g++ \
        make \
        automake \
        autoconf \
        bzip2 \
        unzip \
        wget \
        sox \
        libtool \
        git \
        bc \
        subversion \
        llvm \
        python2.7 \
        python-setuptools \
        python3 \
        python3-setuptools \
        zlib1g-dev \
        ca-certificates \
        gfortran \
        patch \
        ffmpeg \
        python3-pip \
        python-dev \
	vim \
        bsdmainutils \
        icu-devtools \
        gawk && \
    rm -rf /var/lib/apt/lists/*


RUN  pip3 install wheel && pip3 install llvmlite==0.31.0 && \
     pip3 install -r /docker/requirements.txt


# Installing Kaldi
RUN git clone --depth 1 https://github.com/kaldi-asr/kaldi.git /opt/kaldi && \
    cd /opt/kaldi/tools && \
    ./extras/install_mkl.sh && \
    make -j $(nproc) && \
    cd /opt/kaldi/src && \
    ./configure --shared && \
    make depend -j $(nproc) && \
    make -j $(nproc) && \
    cd /opt/kaldi/tools && \
    apt-get install python-dev -y && \
    ./extras/install_irstlm.sh  && \
    ./extras/install_phonetisaurus.sh && \
    sed -i "s/env[[:space:]]python/env python2.7/g" /opt/kaldi/tools/phonetisaurus-g2p/src/scripts/phonetisaurus-apply     
    find /opt/kaldi -type f \( -name "*.o" -o -name "*.la" -o -name "*.a" \) -exec rm {} \; && \
    find /opt/intel -type f -name "*.a" -exec rm {} \; && \
    find /opt/intel -type f -regex '.*\(_mc.?\|_mic\|_thread\|_ilp64\)\.so' -exec rm {} \; && \
    rm -rf /docker/.git

WORKDIR /ALTA


ENTRYPOINT ["/bin/bash"]



