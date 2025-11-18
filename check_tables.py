#!/usr/bin/env python3
"""Script para verificar si las tablas de Social Ads existen en Databricks"""

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

# Tablas a verificar
tables_to_check = [
    ('curated', 'social', 'google_ads_account'),
    ('curated', 'social', 'google_user'),
    ('curated', 'social', 'google_merchant_center_account'),
    ('curated', 'social', 'tiktok_user'),
]

print("=" * 80)
print("VERIFICACIÓN DE TABLAS EN DATABRICKS")
print("=" * 80)

for catalog, schema, table in tables_to_check:
    try:
        # Intentar hacer DESCRIBE TABLE
        query = f"DESCRIBE TABLE {catalog}.{schema}.{table}"
        cursor.execute(query)
        result = cursor.fetchall()
        print(f"\n✅ {catalog}.{schema}.{table} - EXISTE")
        print(f"   Columnas encontradas: {len(result)}")
    except Exception as e:
        error_msg = str(e)
        if "TABLE_OR_VIEW_NOT_FOUND" in error_msg or "does not exist" in error_msg.lower():
            print(f"\n❌ {catalog}.{schema}.{table} - NO EXISTE")
        else:
            print(f"\n⚠️  {catalog}.{schema}.{table} - ERROR: {error_msg}")

# Verificar si el schema existe
print("\n" + "=" * 80)
print("VERIFICANDO SCHEMAS EN CATALOG 'curated'")
print("=" * 80)
try:
    cursor.execute("SHOW SCHEMAS IN curated")
    schemas = cursor.fetchall()
    schema_names = [row[0] for row in schemas]
    print(f"\nSchemas encontrados en 'curated': {schema_names}")
    if 'social' in schema_names:
        print("✅ Schema 'social' existe en catalog 'curated'")
    else:
        print("❌ Schema 'social' NO existe en catalog 'curated'")
except Exception as e:
    print(f"Error verificando schemas: {e}")

# Verificar catálogos disponibles
print("\n" + "=" * 80)
print("VERIFICANDO CATALOGS DISPONIBLES")
print("=" * 80)
try:
    cursor.execute("SHOW CATALOGS")
    catalogs = cursor.fetchall()
    catalog_names = [row[0] for row in catalogs]
    print(f"\nCatalogs encontrados: {catalog_names}")
    if 'curated' in catalog_names:
        print("✅ Catalog 'curated' existe")
    else:
        print("❌ Catalog 'curated' NO existe")
except Exception as e:
    print(f"Error verificando catalogs: {e}")

cursor.close()
connection.close()

print("\n" + "=" * 80)
print("VERIFICACIÓN COMPLETA")
print("=" * 80)

