# syntax=docker/dockerfile:1

# gluetun built from the upstream release tag on a current Go toolchain, with
# the final stage on the shared Alpine base. Upstream only rebuilds its tagged
# images on release, so the Alpine packages and Go standard library in the
# upstream tag age between releases; this image moves both every week, and
# bumps the Go modules Trivy flags (see the RUN below).
# Differences from upstream: no legacy OpenVPN 2.5 package (it comes from the
# Alpine 3.17 repository and is unpatched); OpenVPN 2.6 from the current
# Alpine release is kept. The environment defaults below are upstream's,
# verbatim, so configuration is unchanged. Runs as root: the VPN tunnel and
# firewall need NET_ADMIN.
FROM docker.io/library/golang:1.26-alpine3.23 AS build
ARG VERSION="v3.41.3"
RUN apk add --no-cache git
WORKDIR /src
RUN git clone --depth 1 --branch "${VERSION}" https://github.com/qdm12/gluetun.git . \
    && go mod download
# Upstream pins these modules in go.mod at the tag and only moves them on its
# next release; the 2026-11-06 scan of the pure tag build had 20 HIGH findings
# in them (x/crypto, x/net, x/text, klauspost/compress). Move them to their
# current releases before building; the application code is unchanged.
RUN go get golang.org/x/crypto@latest golang.org/x/net@latest golang.org/x/text@latest github.com/klauspost/compress@latest \
    && go mod tidy
ENV CGO_ENABLED=0
RUN commit="$(git rev-parse --short HEAD)" \
    && created="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    && GOARCH=amd64 go build -trimpath -ldflags="-s -w \
        -X 'main.version=${VERSION}' \
        -X 'main.created=${created}' \
        -X 'main.commit=${commit}' \
        " -o /gluetun-entrypoint cmd/gluetun/main.go

FROM ghcr.io/rake-pro/alpine-base:1.0@sha256:f62113d237739786f9b4419271e4625f509374576b50c8cb8ea4fc882952d168
ARG VERSION
LABEL org.opencontainers.image.source="https://github.com/Rake-Pro/gluetun" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.documentation="https://github.com/qdm12/gluetun-wiki"
ENV VPN_SERVICE_PROVIDER=pia \
    VPN_TYPE=openvpn \
    # Common VPN options
    VPN_INTERFACE=tun0 \
    # OpenVPN
    OPENVPN_ENDPOINT_IP= \
    OPENVPN_ENDPOINT_PORT= \
    OPENVPN_PROTOCOL=udp \
    OPENVPN_USER= \
    OPENVPN_PASSWORD= \
    OPENVPN_USER_SECRETFILE=/run/secrets/openvpn_user \
    OPENVPN_PASSWORD_SECRETFILE=/run/secrets/openvpn_password \
    OPENVPN_VERSION=2.6 \
    OPENVPN_VERBOSITY=1 \
    OPENVPN_FLAGS= \
    OPENVPN_CIPHERS= \
    OPENVPN_AUTH= \
    OPENVPN_PROCESS_USER=root \
    OPENVPN_MSSFIX= \
    OPENVPN_CUSTOM_CONFIG= \
    # Wireguard
    WIREGUARD_ENDPOINT_IP= \
    WIREGUARD_ENDPOINT_PORT= \
    WIREGUARD_CONF_SECRETFILE=/run/secrets/wg0.conf \
    WIREGUARD_PRIVATE_KEY= \
    WIREGUARD_PRIVATE_KEY_SECRETFILE=/run/secrets/wireguard_private_key \
    WIREGUARD_PRESHARED_KEY= \
    WIREGUARD_PRESHARED_KEY_SECRETFILE=/run/secrets/wireguard_preshared_key \
    WIREGUARD_PUBLIC_KEY= \
    WIREGUARD_ALLOWED_IPS= \
    WIREGUARD_PERSISTENT_KEEPALIVE_INTERVAL=0 \
    WIREGUARD_ADDRESSES= \
    WIREGUARD_ADDRESSES_SECRETFILE=/run/secrets/wireguard_addresses \
    WIREGUARD_MTU=1320 \
    WIREGUARD_IMPLEMENTATION=auto \
    # VPN server filtering
    SERVER_REGIONS= \
    SERVER_COUNTRIES= \
    SERVER_CITIES= \
    SERVER_HOSTNAMES= \
    SERVER_CATEGORIES= \
    # # Mullvad only:
    ISP= \
    OWNED_ONLY=no \
    # # Private Internet Access only:
    PRIVATE_INTERNET_ACCESS_OPENVPN_ENCRYPTION_PRESET= \
    VPN_PORT_FORWARDING=off \
    VPN_PORT_FORWARDING_LISTENING_PORT=0 \
    VPN_PORT_FORWARDING_PROVIDER= \
    VPN_PORT_FORWARDING_STATUS_FILE="/tmp/gluetun/forwarded_port" \
    VPN_PORT_FORWARDING_USERNAME= \
    VPN_PORT_FORWARDING_PASSWORD= \
    VPN_PORT_FORWARDING_UP_COMMAND= \
    VPN_PORT_FORWARDING_DOWN_COMMAND= \
    # # Cyberghost only:
    OPENVPN_CERT= \
    OPENVPN_KEY= \
    OPENVPN_CLIENTCRT_SECRETFILE=/run/secrets/openvpn_clientcrt \
    OPENVPN_CLIENTKEY_SECRETFILE=/run/secrets/openvpn_clientkey \
    # # VPNSecure only:
    OPENVPN_ENCRYPTED_KEY= \
    OPENVPN_ENCRYPTED_KEY_SECRETFILE=/run/secrets/openvpn_encrypted_key \
    OPENVPN_KEY_PASSPHRASE= \
    OPENVPN_KEY_PASSPHRASE_SECRETFILE=/run/secrets/openvpn_key_passphrase \
    # # Nordvpn only:
    SERVER_NUMBER= \
    # # PIA only:
    SERVER_NAMES= \
    # # VPNUnlimited and ProtonVPN only:
    STREAM_ONLY= \
    FREE_ONLY= \
    # # ProtonVPN only:
    SECURE_CORE_ONLY= \
    TOR_ONLY= \
    # # Surfshark only:
    MULTIHOP_ONLY= \
    # # VPN Secure only:
    PREMIUM_ONLY= \
    # # PIA and ProtonVPN only:
    PORT_FORWARD_ONLY= \
    # Firewall
    FIREWALL_ENABLED_DISABLING_IT_SHOOTS_YOU_IN_YOUR_FOOT=on \
    FIREWALL_VPN_INPUT_PORTS= \
    FIREWALL_INPUT_PORTS= \
    FIREWALL_OUTBOUND_SUBNETS= \
    FIREWALL_DEBUG=off \
    # Logging
    LOG_LEVEL=info \
    # Health
    HEALTH_SERVER_ADDRESS=127.0.0.1:9999 \
    HEALTH_TARGET_ADDRESSES=cloudflare.com:443,github.com:443 \
    HEALTH_ICMP_TARGET_IPS=1.1.1.1,8.8.8.8 \
    HEALTH_SMALL_CHECK_TYPE=icmp \
    HEALTH_RESTART_VPN=on \
    # DNS
    DNS_SERVER=on \
    DNS_UPSTREAM_RESOLVER_TYPE=DoT \
    DNS_UPSTREAM_RESOLVERS=cloudflare \
    DNS_BLOCK_IPS= \
    DNS_BLOCK_IP_PREFIXES= \
    DNS_CACHING=on \
    DNS_UPSTREAM_IPV6=off \
    BLOCK_MALICIOUS=on \
    BLOCK_SURVEILLANCE=off \
    BLOCK_ADS=off \
    DNS_UNBLOCK_HOSTNAMES= \
    DNS_REBINDING_PROTECTION_EXEMPT_HOSTNAMES= \
    DNS_UPDATE_PERIOD=24h \
    DNS_ADDRESS=127.0.0.1 \
    DNS_KEEP_NAMESERVER=off \
    # HTTP proxy
    HTTPPROXY= \
    HTTPPROXY_LOG=off \
    HTTPPROXY_LISTENING_ADDRESS=":8888" \
    HTTPPROXY_STEALTH=off \
    HTTPPROXY_USER= \
    HTTPPROXY_PASSWORD= \
    HTTPPROXY_USER_SECRETFILE=/run/secrets/httpproxy_user \
    HTTPPROXY_PASSWORD_SECRETFILE=/run/secrets/httpproxy_password \
    # Shadowsocks
    SHADOWSOCKS=off \
    SHADOWSOCKS_LOG=off \
    SHADOWSOCKS_LISTENING_ADDRESS=":8388" \
    SHADOWSOCKS_PASSWORD= \
    SHADOWSOCKS_PASSWORD_SECRETFILE=/run/secrets/shadowsocks_password \
    SHADOWSOCKS_CIPHER=chacha20-ietf-poly1305 \
    # Control server
    HTTP_CONTROL_SERVER_LOG=on \
    HTTP_CONTROL_SERVER_ADDRESS=":8000" \
    HTTP_CONTROL_SERVER_AUTH_CONFIG_FILEPATH=/gluetun/auth/config.toml \
    HTTP_CONTROL_SERVER_AUTH_DEFAULT_ROLE="{}" \
    # Server data updater
    UPDATER_PERIOD=0 \
    UPDATER_MIN_RATIO=0.8 \
    UPDATER_VPN_SERVICE_PROVIDERS= \
    UPDATER_PROTONVPN_EMAIL= \
    UPDATER_PROTONVPN_PASSWORD= \
    # Public IP
    PUBLICIP_FILE="/tmp/gluetun/ip" \
    PUBLICIP_ENABLED=on \
    PUBLICIP_API=ipinfo,ifconfigco,ip2location,cloudflare \
    PUBLICIP_API_TOKEN= \
    # Storage
    STORAGE_FILEPATH=/gluetun/servers.json \
    # Pprof
    PPROF_ENABLED=no \
    PPROF_BLOCK_PROFILE_RATE=0 \
    PPROF_MUTEX_PROFILE_RATE=0 \
    PPROF_HTTP_SERVER_ADDRESS=":6060" \
    # Extras
    VERSION_INFORMATION=on \
    TZ= \
    PUID=1000 \
    PGID=1000
ENTRYPOINT ["/gluetun-entrypoint"]
EXPOSE 8000/tcp 8888/tcp 8388/tcp 8388/udp
HEALTHCHECK --interval=5s --timeout=5s --start-period=10s --retries=3 CMD /gluetun-entrypoint healthcheck
RUN apk add --no-cache openvpn iptables iptables-legacy \
    && mv /usr/sbin/openvpn /usr/sbin/openvpn2.6 \
    && rm -rf /etc/openvpn/*.sh /usr/lib/openvpn/plugins/openvpn-plugin-down-root.so \
    && deluser openvpn \
    && mkdir /gluetun
COPY --from=build /gluetun-entrypoint /gluetun-entrypoint
