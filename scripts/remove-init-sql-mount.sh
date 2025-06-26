#!/bin/bash

# Remove a linha de montagem do init.sql do docker-compose.yml, se existir
sed -i '/init.sql:\/docker-entrypoint-initdb.d\/init.sql/d' docker-compose.yml

echo "Linha de montagem do init.sql removida do docker-compose.yml (se existia)." 