FROM nginx:stable

LABEL description="Nginx webserver with TSL as a Reverse Proxy for RESTful API"
LABEL license="MIT"
LABEL maintainer="Aleksey Chernyaev <a.chernyaev.work@gmail.com>"

# Generate TSL certificate (keep in separate layer to avoid cache invalidation)
COPY openssl.conf /tmp/confs/openssl.conf
RUN openssl ecparam -genkey -name prime256v1 -out /etc/ssl/private/Voib2lab.ru_ECDSA.pem \
    && openssl req -new -x509 -days 3650 -config /tmp/confs/openssl.conf -extensions v3_req \
        -key /etc/ssl/private/Voib2lab.ru_ECDSA.pem \
        -out /etc/ssl/certs/Voib2lab.ru_ECDSA_Self_Signed_ROOT.pem
# Fetch standard DHE parameters for 2048bit key.
RUN curl -qfsL --create-dirs \
    -o /etc/nginx/dhparam/dhparam.pem \
    https://ssl-config.mozilla.org/ffdhe2048.txt
# Copy nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf
# Clean-up
RUN rm -rf /tmp/*

EXPOSE 80/tcp
EXPOSE 443/tcp

STOPSIGNAL SIGQUIT

HEALTHCHECK --interval=1m --retries=1 --start-period=30s \
    CMD service nginx status &> /dev/null || exit 1

CMD ["nginx", "-g", "daemon off;"]