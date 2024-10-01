FROM node:alpine
RUN npm install -g htmlhint@latest
ARG WORKSPACE
COPY $WORKSPACE /workspace
WORKDIR /workspace

ENTRYPOINT ["htmlhint"]
