ARG OTP_VSN=25.2.3
FROM mongooseim/cimg-erlang:$OTP_VSN

# required packages
RUN sudo apt-get update && sudo apt-get install -y \
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
    sudo apt-get clean

COPY ./builder/build.sh /build.sh
VOLUME /builds

CMD ["/build.sh"]
