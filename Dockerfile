ARG OS_VERSION=8.6
ARG BASE_IMAGE=almalinux:${OS_VERSION}
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.source="https://github.com/mtwes2718/docker_minislurm" \
      org.opencontainers.image.authors="m.t.west@exeter.ac.uk" \
      org.opencontainers.image.title="minislurm" \
      org.opencontainers.image.description="Slurm All-in-one Docker container on ${BASE_IMAGE}" \
      org.opencontainers.image.licenses="MIT"

ENV PATH "/root/.pyenv/shims:/root/.pyenv/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/bin"

EXPOSE 6817 6818 6819 6820 3306

# Installing the Fedora EPEL repository for extra packages
RUN set -ex \
    && dnf update -y \
    && dnf install -y 'dnf-command(config-manager)' \
    && dnf config-manager --set-enabled powertools \
    && dnf install -y epel-release \
    # Install common DNF utilities packages
    && dnf install -y \
        autoconf \
        cmake \
        curl \
        file \
        gcc \
        gcc-c++ \
        git \
        gnupg \
        make \
        man \
        mariadb-server \
        munge \
        openssl \
        patch \
        pkgconfig \
        psmisc \
        python39 \
        python39-pip \
        tini \
        tk \
        supervisor \
        wget \
        which \
        vim-enhanced \
    # Install Slurm, the daemons, and their dependencies
    && dnf install -y \
        slurm \
        slurm-slurmd \
        slurm-slurmctld \
        slurm-slurmdbd \
    && dnf clean all \
    && dnf autoremove

# Define Slurm user & group along with it's restricted storage directories
RUN set -ex \
    && groupadd -r slurm \
    && useradd -r -g slurm slurm \
    && mkdir -p \
        /etc/sysconfig/slurm \
        /var/spool/slurmd \
        /var/spool/slurmctld \
        /var/log/slurm \
        /var/run/slurm \
    && chown -R slurm:slurm /var/spool/slurmd \
        /var/spool/slurmctld \
        /var/log/slurm \
        /var/run/slurm \
    && /sbin/create-munge-key

RUN dd if=/dev/random of=/etc/slurm/jwt_hs256.key bs=32 count=1 \
    && chmod 600 /etc/slurm/jwt_hs256.key \
    && chown slurm.slurm /etc/slurm/jwt_hs256.key

# New Slurm daemon config files
COPY --chown=slurm files/slurm/slurm.conf files/slurm/gres.conf files/slurm/slurmdbd.conf /etc/slurm/
COPY files/supervisord.conf /etc/
# Restrict access to the database daemon
RUN chmod 0600 /etc/slurm/slurmdbd.conf

# Mark externally mounted volumes
VOLUME ["/var/lib/mysql", "/var/lib/slurmd", "/var/spool/slurm", "/var/log/slurm"]

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["/tini", "--", "/usr/local/bin/docker-entrypoint.sh"]
CMD ["/bin/bash"]
