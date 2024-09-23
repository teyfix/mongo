ARG MONGO_VERSION=7

FROM mongo:${MONGO_VERSION} AS mongo

RUN apt-get update && apt-get install -y curl build-essential python3 libkrb5-dev iputils-ping
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - && apt-get install -y nodejs
RUN npm install -g run-rs

WORKDIR /usr/src/app
