FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    sudo \
    bash \
    bash-completion \
    build-essential \
    software-properties-common \
    git \
    vim \
    libssl-dev \
    zlib1g-dev \
    unixodbc-dev \
    gnupg \
    wget \
    curl \
    tar \
    unzip \
    zip \
    gzip \
    rsync \
    telnet \
    apt-transport-https && \
    rm -rf /var/lib/apt/lists/*

# Install erlang
ARG OTP_VERSION="23.2"
RUN wget http://packages.erlang-solutions.com/erlang-solutions_2.0_all.deb && \
    dpkg -i erlang-solutions_2.0_all.deb && \
    apt-get update && \
    apt-get install -y esl-erlang=1:$OTP_VERSION-1 && \
    apt-get clean

# Install rebar
ARG REBAR3_VERSION="3.14.2"
RUN set -xe \
    && REBAR3_DOWNLOAD_URL="https://github.com/erlang/rebar3/releases/download/${REBAR3_VERSION}/rebar3" \
    && REBAR3_DOWNLOAD_SHA256="1b23a38dbc22140106c13964d2b2c1dc812d6e4244a863cba02f7d9d1afe3608" \
    && curl -fSL -o rebar3 "$REBAR3_DOWNLOAD_URL" \
    && echo "$REBAR3_DOWNLOAD_SHA256 rebar3" | sha256sum -c - \
    && install -v ./rebar3 /usr/local/bin/

COPY ./builder/build.sh /build.sh
VOLUME /builds

CMD ["/sbin/my_init"]
