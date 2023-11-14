
FROM ghcr.io/kdab/hotspot-ubuntu22.04-dependencies
ARG DEBIAN_FRONTEND=noninteractive

RUN apt update && apt -y upgrade

### Git ###
# RUN apt install -y software-properties-common
# RUN add-apt-repository -y ppa:git-core/ppa
# # https://github.com/git-lfs/git-lfs/blob/main/INSTALLING.md
# RUN curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash
RUN apt install -y git git-lfs

### PERF
RUN apt install -y bison flex libelf-dev libnewt-dev libdw-dev libaudit-dev libiberty-dev libunwind-dev \
  libcap-dev libzstd-dev liblzma-dev libnuma-dev libssl-dev systemtap-sdt-dev libbabeltrace-ctf-dev \
  libperl-dev libtraceevent-dev \
  binutils-dev gcc-multilib \
  python3-dev \
  libgtk2.0-dev
#  asciidoc                 optional, only for manpages, depdencies are huge

# TODO: leave clean "install only", in this case only the following dependencies are needed
# RUN apt install -y linux-tools-generic libtraceevent1 libpython3-dev

# use the following mirror only when needed
# ENV PERF_VER=v6.1
# ENV KERNEL_REPO=https://git.kernel.org/pub/scm/linux/kernel/git/perf/perf-tools.git
# see https://kernel.googlesource.com/pub/scm/linux/kernel/git/acme/linux/+refs
# ENV PERF_VER=perf-tools-fixes-for-v6.1-1-2023-01-06
ENV PERF_VER=cbe7d3e3c90b34dc3d12041911f3ecf3d28d7ad5
ENV KERNEL_REPO=https://github.com/torvalds/linux.git
ENV LINUX_ROOT=/opt/linux

RUN mkdir -p ${LINUX_ROOT}
WORKDIR ${LINUX_ROOT}/..
RUN git clone --depth 1 --filter=blob:none --sparse ${KERNEL_REPO}
WORKDIR ${LINUX_ROOT}
RUN git sparse-checkout set tools scripts arch
RUN git fetch --depth 1 origin ${PERF_VER}
RUN make -C tools/perf -j $(nproc) PYTHON=/usr/bin/python3

ENV PATH=${PERF_EXEC_PATH}:${PATH}
ENV PERF_EXEC_PATH=${LINUX_ROOT}/tools/perf

RUN sysctl kernel.perf_event_paranoid=-1

### GDB
RUN apt install -y gdb
### system-wide KDE+QT pretty-printers for GDB
RUN mkdir -p /etc/gdb/printers
#RUN curl -"https://invent.kde.org/kdevelop/kdevelop/-/raw/master/plugins/gdb/printers/gdbinit" -o /etc/gdb/printers/gdbinit
RUN curl -"https://invent.kde.org/kdevelop/kdevelop/-/raw/master/plugins/gdb/printers/elper.py" -o /etc/gdb/printers/helper.py
RUN curl -"https://invent.kde.org/kdevelop/kdevelop/-/raw/master/plugins/gdb/printers/kde.py"   -o /etc/gdb/printers/kde.py
RUN curl -"https://invent.kde.org/kdevelop/kdevelop/-/raw/master/plugins/gdb/printers/qt.py"    -o /etc/gdb/printers/qt.py

COPY <<-EOT /etc/gdb/gdbinit
python
  import sys
  sys.path.insert(0, '/etc/gdb/printers')
  from qt import register_qt_printers
  from kde import register_kde_printers
  register_qt_printers  (None)
  register_kde_printers (None)
end
EOT

### aditional checking tools
RUN apt install -y ruby-rubygems npm
RUN gem update
RUN gem install mdl
RUN npm install -g markdown-toc
RUN apt install -y pre-commit

### aditional tools for use in gitpod
RUN apt install -y clang-format clangd gdb

### vnc config
RUN apt install -y tigervnc-standalone-server tigervnc-xorg-extension \
	dbus dbus-x11 gnome-keyring xfce4 xfce4-terminal \
	xdg-utils x11-xserver-utils pip \
  novnc python3-novnc

RUN apt install -y locales
RUN locale-gen en_US.UTF-8

### Gitpod user ###
# '-l': see https://docs.docker.com/develop/develop-images/dockerfile_best-practices/#user
RUN apt install -y sudo
RUN useradd -l -u 33333 -G sudo -md /home/gitpod -s /bin/bash -p gitpod gitpod \
#     # Remove `use_pty` option and enable passwordless sudo for users in the 'sudo' group
      && sed -i.bkp -e '/Defaults\tuse_pty/d' -e 's/%sudo\s\+ALL=(ALL\(:ALL\)\?)\s\+ALL/%sudo ALL=NOPASSWD:ALL/g' /etc/sudoers \
#     # To emulate the workspace-session behavior within dazzle build env
      && mkdir /workspace && chown -hR gitpod:gitpod /workspace

RUN curl "https://raw.githubusercontent.com/gitpod-io/workspace-images/axonasif/add_docs/chunks/tool-vnc/gp-vncsession" -o /usr/bin/gp-vncsession
RUN sed -i 's#/opt/novnc/utils/novnc_proxy#/usr/share/novnc/utils/launch.sh#' /usr/bin/gp-vncsession
#RUN mkdir -p /opt/novnc
#COPY <<-EOT /opt/novnc/index.html
#<html><head><meta http-equiv="Refresh" content="0; url=vnc.html?autoconnect=true&reconnect=true&resize=scale"></head></html>
#EOT
RUN ln -s /usr/share/novnc/vnc.html /usr/share/novnc/index.html

RUN chmod 0755 /usr/bin/gp-vncsession \
	&& printf '%s\n' 'export DISPLAY=:0' \
	'test -e "$GITPOD_REPO_ROOT" && gp-vncsession' >> "/home/gitpod/.bashrc"
RUN curl "https://github.com/gitpod-io/workspace-images/blob/axonasif/add_docs/chunks/tool-vnc/.xinitrc" > /home/gitpod/.xinitrc

# custom Bash prompt
# RUN { echo && echo "PS1='\[\033[01;32m\]\u\[\033[00m\] \[\033[01;34m\]\w\[\033[00m\]\$(__git_ps1 \" (%s)\") $ '" ; } >> /home/gitpod/.bashrc

RUN chown -R gitpod:gitpod /home/gitpod
