
FROM gitea/act_runner:0.2.11
COPY --chown=root:root root-ca.crt /usr/local/share/ca-certificates/crucible-ca.crt
RUN apk update --no-cache && \
  apk --no-cache add ca-certificates && \
  update-ca-certificates