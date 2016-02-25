FROM phusion/baseimage
MAINTAINER Michał Piotrowski <michal.piotrowski@erlang-solutions.com>

# required packages
RUN apt-get update && apt-get install -y \
    bash \
    bash-completion \
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
    libpam0g-dev &&\
    apt-get clean

COPY ./member/clusterize /clusterize
COPY ./member/start.sh /start.sh
COPY ./member/mongooseim.tar.gz mongooseim.tar.gz
VOLUME /member

EXPOSE 4369 5222 5269 5280 9100

ENTRYPOINT ["/start.sh"]
