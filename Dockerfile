FROM        krallin/ubuntu-tini:trusty

WORKDIR /buildbot

# Install security updates and required packages
RUN apt-get update \
&&  DEBIAN_FRONTEND=noninteractive \
    apt-get -y install -q \
       alien \
       build-essential \
       chrpath \
       cmake \
       cpio \
       curl \
       diffstat \
       docbook-xsl \
       gawk \
       git \
       libffi-dev \
       libssl-dev \
       locales \
       net-tools \
       default-jre-headless \
       python-dev \
       python3 \
       subversion \
       texinfo \
       wget \
       xsltproc \
&&  rm -rf /var/lib/apt/lists/*

# Generate UTF-8 locale for python3
RUN echo "en_US.UTF-8 UTF-8" >> /var/lib/locales/supported.d/local \
&&  dpkg-reconfigure -f noninteractive locales \
&&  update-locale LANG=en_US.UTF-8

# Set locale environment
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# Reset /bin/sh to bash instead of dash
RUN echo "dash dash/sh boolean false" \
|   debconf-set-selections -v \
&&  dpkg-reconfigure -f noninteractive dash

# Install required python packages, and twisted
ARG BUILDBOT_VERSION
RUN wget https://bootstrap.pypa.io/get-pip.py \
&&  python get-pip.py --no-cache-dir \
&&  pip --no-cache-dir install \
    'twisted[tls]' \
    buildbot-worker==${BUILDBOT_VERSION} \
&&  rm -rf get-pip.py

# Install software for image signing
ARG PTK_HSM_HOST="127.0.0.1"
ARG PTK_URI="http://127.0.0.1/610-009981-015_SW_PTK_5.3_Client_RevA.tar"
RUN curl ${PTK_URI} \
|   tar -v -x -C /tmp \
&&  alien --to-deb --install --scripts /tmp/610-009981-015_SW_PTK_5.3_Client_RevA/SDKs/Linux64/ptkc_sdk/PTKcpsdk-5.3.0-16.x86_64.rpm \
&&  alien --to-deb --install --scripts /tmp/610-009981-015_SW_PTK_5.3_Client_RevA/SDKs/Linux64/ptkc_runtime/PTKcprt-5.3.0-15.x86_64.rpm \
&&  alien --to-deb --install --scripts /tmp/610-009981-015_SW_PTK_5.3_Client_RevA/SDKs/Linux64/network_hsm_access_provider/PTKnethsm-5.3.0-15.x86_64.rpm \
&&  echo "ET_HSM_NETCLIENT_SERVERLIST=${PTK_HSM_HOST}" > /etc/default/et_hsm \
&&  echo "/opt/safenet/protecttoolkit5/ptk/lib" > /etc/ld.so.conf.d/safenet_ptk.conf \
&&  ldconfig -v \
&&  rm -rf /tmp/610-009981-015_SW_PTK_5.3_Client_RevA/

# Create buildbot user
ARG BUILDBOT_UID=1000
COPY buildbot/ /home/buildbot/
RUN useradd --comment "Buildbot Server" --home-dir "/home/buildbot" --shell "/bin/bash" --uid ${BUILDBOT_UID} --user-group buildbot \
&&  mkdir -p --mode=0700 "/home/buildbot/.ssh" \
&&  chown -v -R buildbot:buildbot "/buildbot" \
&&  chown -v -R buildbot:buildbot "/home/buildbot"

USER buildbot
CMD ["/home/buildbot/start.sh"]
