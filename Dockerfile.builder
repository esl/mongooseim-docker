ARG OTP_VSN=27.3.4
FROM erlangsolutions/erlang:ubuntu-noble-$OTP_VSN

# required packages
RUN apt-get update && apt-get install -y \
    bash \
    wget \
    git \
    make \
    gcc \
    g++ \
    vim \
    bash-completion \
    libc6-dev \
    libncurses5-dev \
    libssl-dev \
    libexpat1-dev \
    libpam0g-dev \
    unixodbc-dev \
    gnupg \
    zlib1g-dev && \
    apt-get clean

COPY ./builder/build.sh /build.sh
VOLUME /builds

CMD ["/build.sh"]
