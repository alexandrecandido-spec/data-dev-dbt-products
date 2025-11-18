#!/usr/bin/env python3
"""Script para buscar las tablas de Social Ads en todos los catalogs disponibles"""

import os
import yaml
from databricks import sql

# Leer configuración de dbt profiles
profiles_path = os.path.expanduser("~/.dbt/profiles.yml")
with open(profiles_path, 'r') as f:
    profiles = yaml.safe_load(f)

# Obtener configuración de dev
config = profiles['nubeproduct']['outputs']['dev']

# Conectar a Databricks
connection = sql.connect(
    server_hostname=config['host'],
    http_path=config['http_path'],
    access_token=config['token']
)

cursor = connection.cursor()

# Tablas a buscar
tables_to_find = [
    'google_ads_account',
    'google_user',
    'google_merchant_center_account',
    'tiktok_user',
]

# Catalogs disponibles
catalogs = ['billing_data', 'bronze_risk', 'cloudability', 'data_products_dev', 'data_products_prd', 
            'ds_catalog', 'ds_outputs_dev', 'ds_outputs_prd', 'hive_metastore', 'raw', 
            'risk_dev', 'risk_prd', 'risk_stg', 'samples', 'system']

print("=" * 80)
print("BÚSQUEDA DE TABLAS EN TODOS LOS CATALOGS")
print("=" * 80)

found_tables = []

for catalog in catalogs:
    try:
        # Obtener schemas en este catalog
        cursor.execute(f"SHOW SCHEMAS IN {catalog}")
        schemas = cursor.fetchall()
        schema_names = [row[0] for row in schemas]
        
        for schema in schema_names:
            try:
                # Obtener tablas en este schema
                cursor.execute(f"SHOW TABLES IN {catalog}.{schema}")
                tables = cursor.fetchall()
                table_names = [row[1] for row in tables]  # El nombre está en la columna 1
                
                # Buscar nuestras tablas
                for table_name in tables_to_find:
                    if table_name.lower() in [t.lower() for t in table_names]:
                        found_tables.append((catalog, schema, table_name))
                        print(f"\n✅ ENCONTRADA: {catalog}.{schema}.{table_name}")
            except Exception as e:
                # Ignorar errores de acceso a schemas
                pass
    except Exception as e:
        # Ignorar errores de acceso a catalogs
        pass

print("\n" + "=" * 80)
print("RESUMEN")
print("=" * 80)

if found_tables:
    print(f"\n✅ Se encontraron {len(found_tables)} tabla(s):")
    for catalog, schema, table in found_tables:
        print(f"   - {catalog}.{schema}.{table}")
else:
    print(f"\n❌ No se encontraron las tablas en ningún catalog:")
    for table in tables_to_find:
        print(f"   - {table}")

cursor.close()
connection.close()

