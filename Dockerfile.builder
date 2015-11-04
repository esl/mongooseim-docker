FROM ubuntu:14.10
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

# add esl packages
RUN wget https://packages.erlang-solutions.com/erlang-solutions_1.0_all.deb \
    && dpkg -i erlang-solutions_1.0_all.deb \
    && wget http://packages.erlang-solutions.com/debian/erlang_solutions.asc\
    && apt-key add erlang_solutions.asc \
    && apt-get update \
    && apt-get install -y erlang-base \
                          erlang-dev \
                          erlang \
                          erlang-dialyzer \
                          erlang-reltool

COPY ./fs/build.sh /build.sh
VOLUME /builds

ENTRYPOINT ["/build.sh"]
