FROM nvidia/cuda:12.3.1-devel-ubuntu22.04

# ======
# Basic tools
# ======
RUN apt update \
	&& apt install -y --no-install-recommends \
	sudo \
	wget \
	ssh \
	git \
	locales \
	build-essential \
	ed \
	less \
	vim \
	ca-certificates

# http://bugs.python.org/issue19846
# > At the moment, setting "LANG=C" on a Linux system *fundamentally breaks Python 3*, and that's not OK.
ENV LANG C.UTF-8
ENV TZ Asia/Tokyo

# ======
# Python
# ======
# https://github.com/docker-library/python/blob/master/3.10/bookworm/Dockerfile

# ensure local python is preferred over distribution python
ENV PATH /usr/local/bin:$PATH

# https://qiita.com/ay__1130/items/d36b0673de637b675db2
ARG DEBIAN_FRONTEND=noninteractive

# runtime dependencies
RUN set -eux; \
	apt install -y --no-install-recommends \
	libbluetooth-dev \
	openssl \
	libssl-dev \
	libffi-dev \
	libsqlite3-dev \
	tk-dev \
	uuid-dev

ARG PYTHON_GPG_KEY=A035C8C19219BA821ECEA86B64E628F8D684696D
ARG PYTHON_VERSION=3.10.13
ARG PYTHON_TAR_PATH=python.tar.xz
ARG PYTHON_SRC_PATH=/usr/local/src/python

RUN wget -O ${PYTHON_TAR_PATH} "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz"; \
	wget -O ${PYTHON_TAR_PATH}.asc "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz.asc"; \
	GNUPGHOME="$(mktemp -d)"; export GNUPGHOME; \
	gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys "$GPG_KEY"; \
	gpg --batch --verify ${PYTHON_TAR_PATH}.asc ${PYTHON_TAR_PATH}; \
	gpgconf --kill all; \
	rm -rf "$GNUPGHOME" ${PYTHON_TAR_PATH}.asc; \
	mkdir -p ${PYTHON_SRC_PATH}; \
	tar --extract --directory ${PYTHON_SRC_PATH} --strip-components=1 --file ${PYTHON_TAR_PATH}; \
	rm ${PYTHON_TAR_PATH}; \
	\
	cd ${PYTHON_SRC_PATH} ; \
	gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"; \
	./configure \
	--build="$gnuArch" \
	--enable-loadable-sqlite-extensions \
	--enable-optimizations \
	--enable-option-checking=fatal \
	--enable-shared \
	--with-lto \
	--with-system-expat \
	--without-ensurepip \
	; \
	nproc="$(nproc)"; \
	EXTRA_CFLAGS="$(dpkg-buildflags --get CFLAGS)"; \
	LDFLAGS="$(dpkg-buildflags --get LDFLAGS)"; \
	make -j "$nproc" \
	"EXTRA_CFLAGS=${EXTRA_CFLAGS:-}" \
	"LDFLAGS=${LDFLAGS:-}" \
	"PROFILE_TASK=${PROFILE_TASK:-}" \
	; \
	# https://github.com/docker-library/python/issues/784
	# prevent accidental usage of a system installed libpython of the same version
	rm python; \
	make -j "$nproc" \
	"EXTRA_CFLAGS=${EXTRA_CFLAGS:-}" \
	"LDFLAGS=${LDFLAGS:--Wl},-rpath='\$\$ORIGIN/../lib'" \
	"PROFILE_TASK=${PROFILE_TASK:-}" \
	python \
	; \
	make install; \
	\
	# enable GDB to load debugging data: https://github.com/docker-library/python/pull/701
	bin="$(readlink -ve /usr/local/bin/python3)"; \
	dir="$(dirname "$bin")"; \
	mkdir -p "/usr/share/gdb/auto-load/$dir"; \
	cp -vL Tools/gdb/libpython.py "/usr/share/gdb/auto-load/$bin-gdb.py"

# make some useful symlinks that are expected to exist ("/usr/local/bin/python" and friends)
RUN set -eux; \
	for src in idle3 pydoc3 python3 python3-config; do \
	dst="$(echo "$src" | tr -d 3)"; \
	[ -s "/usr/local/bin/$src" ]; \
	[ ! -e "/usr/local/bin/$dst" ]; \
	ln -svT "$src" "/usr/local/bin/$dst"; \
	done

# ======
# Pip & Poetry
# ======

# if this is called "PIP_VERSION", pip explodes with "ValueError: invalid truth value '<VERSION>'"
ARG PYTHON_PIP_VERSION=23.0.1
# https://github.com/docker-library/python/issues/365
ARG PYTHON_SETUPTOOLS_VERSION=65.5.1
# https://github.com/pypa/get-pip
ARG PYTHON_GET_PIP_URL=https://github.com/pypa/get-pip/raw/049c52c665e8c5fd1751f942316e0a5c777d304f/public/get-pip.py
ARG PYTHON_GET_PIP_SHA256=7cfd4bdc4d475ea971f1c0710a5953bcc704d171f83c797b9529d9974502fcc6

RUN set -eux; \
	\
	wget -O get-pip.py "$PYTHON_GET_PIP_URL"; \
	echo "$PYTHON_GET_PIP_SHA256 *get-pip.py" | sha256sum -c -; \
	\
	export PYTHONDONTWRITEBYTECODE=1; \
	\
	python get-pip.py \
	--disable-pip-version-check \
	--no-cache-dir \
	--no-compile \
	"pip==$PYTHON_PIP_VERSION" \
	"setuptools==$PYTHON_SETUPTOOLS_VERSION" \
	; \
	rm -f get-pip.py; \
	pip install poetry

# ======
# R
# ======
# https://github.com/rocker-org/rocker/blob/master/r-base/4.3.2/Dockerfile
RUN apt install -y --no-install-recommends \
	liblapack-dev libblas-dev gfortran \
	libxml2-dev \
	libbz2-dev \
	libreadline-dev \
	libpcre2-dev \
	liblzma-dev \
	libcurl4-openssl-dev \
	# https://github.com/rocker-org/rocker-versioned/tree/master/X11
	libx11-dev \
	libxss-dev \
	libxt-dev \
	libxext-dev \
	libsm-dev \
	libicecc-dev \
	libcairo2-dev \
	libharfbuzz-dev libfribidi-dev \
	libfreetype6-dev libpng-dev libtiff5-dev libjpeg-dev \
	xdg-utils \
	fonts-texgyre \
	fonts-noto-cjk fonts-noto-cjk-extra

ARG R_BASE_VERSION=4.3.2
ARG R_TAR_PATH=R.tar.gz
ARG R_SRC_PATH=/usr/local/src/R

COPY install.r /tmp/install.r
RUN set -eux; \
	wget -O ${R_TAR_PATH} "https://cran.r-project.org/src/base/R-${R_BASE_VERSION%%.*}/R-${R_BASE_VERSION}.tar.gz"; \
	mkdir -p ${R_SRC_PATH}; \
	tar --extract --directory ${R_SRC_PATH} --strip-components=1 --file ${R_TAR_PATH}; \
	rm ${R_TAR_PATH}; \
	\
	cd ${R_SRC_PATH}; \
	./configure \
	--prefix=/usr/local \
	# --enable-R-shlib \
	--enable-memory-profiling \
	--with-x \
	--with-cairo \
	--with-blas \
	--with-lapack; \
	make; make install; \
	echo 'local({r <- getOption("repos"); r["CRAN"] <- "https://cran.ism.ac.jp/"; options(repos=r)})' >> /usr/local/lib/R/etc/Rprofile.site; \
	Rscript /tmp/install.r

# ======
# User settings
# ======
ARG USERNAME="vscode"
ARG USER_UID=1000
ARG USER_GID=$USER_UID
ARG HOME="/home/${USERNAME}"
ARG R_LIBS_USER="${HOME}/.local/lib/R"

RUN groupadd --gid ${USER_GID} ${USERNAME} \
	&& useradd --create-home --uid ${USER_UID} --gid ${USER_GID} --shell /bin/bash ${USERNAME} \
	&& echo ${USERNAME} ALL=\(ALL:ALL\) NOPASSWD:ALL > /etc/sudoers.d/${USERNAME} \
	&& chmod 0440 /etc/sudoers.d/${USERNAME}

USER ${USERNAME}

RUN \
	# echo "export PATH=${HOME}/.local/bin:${PATH}" >> /home/vscode/.bashrc \
	# [NOTE]
	# If the directory pointed to by R_LIBS_USER does not exist, then .libPaths() will not contain it.
	# This is documented on ?.libPaths or ?R_LIBS_USER.
	# Only directories which exist at the time will be included.
	#
	# ref. https://stat.ethz.ch/pipermail/r-help/2017-September/449150.html
	mkdir -p ${R_LIBS_USER} \
	# && mkdir -p ${R_LIBS_USER} \
	&& echo "R_LIBS_USER=${R_LIBS_USER}" > ${HOME}/.Renviron

COPY --chown=${USERNAME}:${USERNAME} post-create.sh ${HOME}/.local/bin/post-create.sh
COPY --chown=${USERNAME}:${USERNAME} poetry.toml ${HOME}/.config/pypoetry/config.toml
