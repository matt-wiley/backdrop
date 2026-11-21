FROM ubuntu:26.04

ARG USERNAME=matt
ARG USER_UID=1000
ARG USER_GID=1000

RUN apt-get update \
 && apt-get install -y --no-install-recommends sudo \
 && rm -rf /var/lib/apt/lists/*

# Ubuntu 23.04+ images ship a default "ubuntu" user on UID 1000; remove it to free the ID
RUN userdel -r ubuntu 2>/dev/null || true

RUN groupadd --gid ${USER_GID} ${USERNAME} \
 && useradd --uid ${USER_UID} --gid ${USER_GID} -m -s /bin/bash ${USERNAME} \
 && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
 && chmod 0440 /etc/sudoers.d/${USERNAME}

USER ${USERNAME}
WORKDIR /home/${USERNAME}
