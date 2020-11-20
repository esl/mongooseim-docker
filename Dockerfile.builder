FROM ubuntu:20.04

ARG OTP_VSN=23.1-1

# handle tzdata config in a non-interactive fashion
RUN export DEBIAN_FRONTEND=noninteractive; \
    export DEBCONF_NONINTERACTIVE_SEEN=true; \
    echo 'tzdata tzdata/Areas select Europe' | debconf-set-selections; \
    echo 'tzdata tzdata/Zones/Etc select Warsaw' | debconf-set-selections; \
    apt-get update -qqy \
 && apt-get install -qqy --no-install-recommends \
    tzdata

# required packages
RUN apt-get update -qqy \
 && apt-get install -qqy --no-install-recommends \
    bash \
    bash-completion \
    g++ \
    gcc \
    git \
    gnupg \
    libc6-dev \
    libexpat1-dev \
    libncurses5-dev \
    libpam0g-dev \
    libssl-dev \
    make \
    unixodbc-dev \
    vim \
    wget \
    zlib1g-dev && \
    wget http://packages.erlang-solutions.com/erlang-solutions_2.0_all.deb && \
    dpkg -i erlang-solutions_2.0_all.deb && \
    apt-get update && \
    apt-get install -y esl-erlang=1:$OTP_VSN && \
    apt-get clean

COPY ./builder/build.sh /build.sh
VOLUME /builds

CMD ["/sbin/my_init"]
