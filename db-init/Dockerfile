FROM mcr.microsoft.com/mssql/server:2022-latest
USER root
RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*
COPY init.sh /init.sh
RUN chmod +x /init.sh
USER mssql
ENTRYPOINT ["/init.sh"]
