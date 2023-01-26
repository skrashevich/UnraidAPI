# syntax = docker/dockerfile-upstream:master-labs

FROM golang:alpine as prune
RUN --mount=type=cache,target=/root/.cache/go-build CGO_ENABLED=0 go install github.com/tj/node-prune@latest

FROM --platform=$BUILDPLATFORM node:16.15.0-slim as builder

ENV NODE_ENV=production
ENV APP_ROOT=/app

RUN rm -f /etc/apt/apt.conf.d/docker-clean; echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,target=/var/lib/apt,sharing=locked apt update \
  && apt install -y --no-install-recommends curl

#RUN apk add python3 make g++
#RUN mkdir -p ${APP_ROOT}/secure && mkdir -p ${APP_ROOT}/config && echo '{}' > ${APP_ROOT}/secure/mqttKeys

ADD --link . ${APP_ROOT}
WORKDIR ${APP_ROOT}

RUN npm install
RUN npx browserslist@latest --update-db 
RUN npm run build
#COPY --link --from=prune /go/bin/node-prune /usr/local/bin/node-prune
RUN --mount=type=bind,from=prune,source=/go/bin/node-prune,target=/usr/local/bin/node-prune /usr/local/bin/node-prune

FROM gcr.io/distroless/nodejs16-debian11
ENV NODE_ENV=production
ENV HOST 0.0.0.0
ENV PORT 80
ENV NODE_OPTIONS="--max_old_space_size=4096"
ENV APP_ROOT=/
ENV NUXT_HOST=0.0.0.0

WORKDIR ${APP_ROOT}
COPY --link --from=builder /app /

# Expose the app port
EXPOSE 80

CMD ["/server/index.js"]
