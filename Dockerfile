FROM gcr.io/distroless/static

ARG TARGETOS TARGETARCH

COPY nanomdm-$TARGETOS-$TARGETARCH /app/nanomdm

EXPOSE 9001

WORKDIR /app

ENTRYPOINT ["/app/nanomdm"]
