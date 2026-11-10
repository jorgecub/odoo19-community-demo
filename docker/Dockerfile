# Stage 1: fetch third-party addons at the exact commits in deps/vendor.lock.
FROM debian:bookworm-slim AS vendor
RUN apt-get update \
    && apt-get install -y --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/*
COPY deps/vendor.lock docker/fetch_addons.sh /build/
RUN sh /build/fetch_addons.sh /build/vendor.lock /vendor

# Stage 2: official Odoo image, pinned by digest. It builds nightly, so Odoo
# fixes arrive through a reviewed PR that bumps this digest.
FROM odoo:19.0@sha256:5e755c725b3c43cf0be16d579904e1418300db3a2c44952f928eaddbcb0cc16d
USER root
COPY --from=vendor /vendor /mnt/addons/vendor
COPY addons /mnt/addons/custom
COPY docker/render_conf.py docker/entrypoint-wrapper.sh /usr/local/bin/
RUN chmod 755 /usr/local/bin/render_conf.py /usr/local/bin/entrypoint-wrapper.sh \
    && chown -R odoo:odoo /mnt/addons
USER odoo
ENV ODOO_RC=/tmp/odoo.conf
ENTRYPOINT ["/usr/local/bin/entrypoint-wrapper.sh"]
CMD ["odoo"]
