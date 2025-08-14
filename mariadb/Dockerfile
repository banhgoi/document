FROM mariadb:10.5

# Đảm bảo các công cụ client như mysqldump được cài sẵn
RUN apt-get update && apt-get install -y mariadb-client && rm -rf /var/lib/apt/lists/*