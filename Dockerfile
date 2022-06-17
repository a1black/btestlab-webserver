FROM alpine:latest AS secret_build
WORKDIR /private
COPY openssl.conf .
COPY private/ .
RUN /bin/ash -c '[ ! -f Voib2lab_ECDSA_CERT.pem -o ! -f Voib2lab_ECDSA_KEY.pem ] \
    && apk update -q \
    && apk add -q openssl > /dev/null \
    && openssl ecparam -genkey -name prime256v1 -out Voib2lab_ECDSA_KEY.pem \
    && openssl req -new -x509 -days 3650 -config openssl.conf -extensions v3_req \
        -key Voib2lab_ECDSA_KEY.pem \
        -out Voib2lab_ECDSA_CERT.pem \
    && chmod 644 *.pem'

FROM node:lts-alpine AS html_build
ENV NODE_ENV=production
WORKDIR /app
RUN /bin/ash -c 'apk update -q \
    && apk add -q git > /dev/null \
    && git clone -q --depth 1 https://github.com/a1black/btestlab-webui.git . \
    && npm install -g npm@latest &> /dev/null \
    && npm install --production &> /dev/null \
    && npm run build'

FROM nginx:stable

LABEL description="Nginx webserver with TSL as a Reverse Proxy for RESTful API"
LABEL license="MIT"
LABEL maintainer="Aleksey Chernyaev <a.chernyaev.work@gmail.com>"

COPY --from=secret_build /private/Voib2lab_ECDSA_CERT.pem /etc/ssl/certs/
COPY --from=secret_build /private/Voib2lab_ECDSA_KEY.pem /etc/ssl/private/
COPY --from=html_build /app/build/ /var/www/labui/
COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 80/tcp
EXPOSE 443/tcp

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD curl -qfs --retry 0 -o /dev/null http://localhost/healthcheck || exit 1

STOPSIGNAL SIGQUIT

CMD ["nginx", "-g", "daemon off;"]