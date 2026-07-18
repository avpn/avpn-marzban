FROM gozargah/marzban:v0.8.4

USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends caddy \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /code

COPY start.sh /start.sh
RUN chmod +x /start.sh

ENV SQLALCHEMY_DATABASE_URL=sqlite:////var/lib/marzban/db.sqlite3
ENV XRAY_JSON=/var/lib/marzban/xray_config.json

EXPOSE 8000
EXPOSE 10000

CMD ["/start.sh"]
