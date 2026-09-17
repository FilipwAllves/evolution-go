FROM golang:1.26-alpine AS build
ENV GOTOOLCHAIN=auto

RUN apk update && apk add --no-cache git build-base libjpeg-turbo-dev libwebp-dev

WORKDIR /build

# Copiar apenas arquivos de dependências primeiro para cachear o download
COPY go.mod go.sum ./

# whatsmeow agora vem do proxy oficial (go.mau.fi/whatsmeow, sem replace local) —
# não há mais submódulo whatsmeow-lib para copiar.
# go.sum pode estar defasado (whatsmeow bumpado no go.mod sem Go local): o `tidy` depois do COPY acerta.
RUN go mod download || true

# Copiar o restante do código
COPY . .

RUN go mod tidy && go mod download

ARG VERSION=dev
RUN CGO_ENABLED=1 go build -ldflags "-X main.version=${VERSION}" -o server ./cmd/evolution-go

FROM alpine:3.19.1 AS final

# poppler-utils provides pdftoppm, used to rasterize PDF page 1 for /send/media document thumbnails
RUN apk update && apk add --no-cache tzdata ffmpeg libjpeg-turbo libwebp poppler-utils

WORKDIR /app

COPY --from=build /build/server .
COPY --from=build /build/manager/dist ./manager/dist
COPY --from=build /build/VERSION ./VERSION

ENV TZ=America/Sao_Paulo

ENTRYPOINT ["/app/server"]
