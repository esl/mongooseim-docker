FROM astachurski/docker-gocd
MAINTAINER Radek Szymczyszyn <radoslaw.szymczyszyn@erlang-solutions.com>

# required packages
RUN apt-get update && apt-get install -y \
    wget \
    git \
    make \
    gcc \
    vim \
    bash-completion \
    libc6-dev \
    libncurses5-dev \
    libssl-dev \
    libexpat1-dev \
    libpam0g-dev

COPY ./fs/build.sh /build.sh
VOLUME /builds

ENTRYPOINT ["/build.sh"]
