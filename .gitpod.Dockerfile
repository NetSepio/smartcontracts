FROM gitpod/workspace-full
RUN npm install -g ganache-cli hardhat @graphprotocol/graph-cli
RUN sudo apt install inotify-tools -y
RUN mkdir /home/gitpod/graph-docker && cd /home/gitpod/graph-docker && \
    git clone https://github.com/graphprotocol/graph-node/ && \
    cd graph-node/docker && \
    sed -i -e "s/host.docker.internal/172.17.0.1/g" docker-compose.yml