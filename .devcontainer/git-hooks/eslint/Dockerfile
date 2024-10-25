FROM pipelinecomponents/eslint:amd64-45dabb1

WORKDIR /workspace

ARG WORKSPACE
COPY $WORKSPACE /workspace

ENTRYPOINT ["eslint", "--no-config-lookup"]
