################### Use the image common for both leader and worker
FROM smtcomp-smts:common AS common
USER root

################### Extract SMTS in run stage
FROM satcomp-infrastructure:worker AS infra_worker
USER root

# Install required software for running
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt install -y libgmp-dev

WORKDIR /

# Copy SMTS and solver scripts
COPY --from=common /SMTS SMTS

COPY --chown=ecs-user /init_solver.sh /competition
COPY --chown=ecs-user /worker /competition
# COPY /cleanup /competition
# RUN chmod +x /competition/cleanup
COPY --chown=ecs-user /cleanup /competition
USER ecs-user
RUN chmod +x /competition/init_solver.sh
RUN chmod +x /competition/worker
RUN chmod +x /competition/cleanup
