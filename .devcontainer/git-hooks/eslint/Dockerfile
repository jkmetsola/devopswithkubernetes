FROM node:alpine3.19

WORKDIR /workspace

# hadolint ignore=DL4006
RUN npm init -y && \
    npm pkg set 'name=linter' && \
    yes | npm init @eslint/config@latest --config eslint-config-standard

ARG WORKSPACE
COPY $WORKSPACE /workspace

ENTRYPOINT ["npx", "eslint", "--no-config-lookup"]
