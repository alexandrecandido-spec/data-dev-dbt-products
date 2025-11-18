#!/usr/bin/env python3
"""
Script para ejecutar las consultas de verificación de freemium
Usa la conexión de dbt para conectarse a Databricks
"""

import os
import sys
import yaml
from pathlib import Path
from databricks import sql
from databricks.sql.client import Connection

# Colores para output
class Colors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'

def load_dbt_profile():
    """Carga el perfil de dbt desde ~/.dbt/profiles.yml"""
    profiles_path = Path.home() / ".dbt" / "profiles.yml"
    
    if not profiles_path.exists():
        print(f"{Colors.FAIL}❌ No se encontró el archivo de perfiles de dbt en: {profiles_path}{Colors.ENDC}")
        print(f"{Colors.WARNING}💡 Asegúrate de tener configurado dbt con: dbt debug{Colors.ENDC}")
        sys.exit(1)
    
    with open(profiles_path, 'r') as f:
        profiles = yaml.safe_load(f)
    
    # Buscar el perfil 'nubeproduct'
    if 'nubeproduct' not in profiles:
        print(f"{Colors.FAIL}❌ No se encontró el perfil 'nubeproduct' en profiles.yml{Colors.ENDC}")
        sys.exit(1)
    
    profile = profiles['nubeproduct']
    target = profile.get('target', 'dev')
    
    if 'outputs' not in profile or target not in profile['outputs']:
        print(f"{Colors.FAIL}❌ No se encontró el target '{target}' en el perfil nubeproduct{Colors.ENDC}")
        sys.exit(1)
    
    output = profile['outputs'][target]
    
    return {
        'server_hostname': output['host'],
        'http_path': output['http_path'],
        'access_token': output.get('token') or os.getenv('DBT_TOKEN') or os.getenv('DATABRICKS_TOKEN'),
        'catalog': output.get('catalog', 'data_products_dev'),
        'schema': output.get('schema', 'testing')
    }

def execute_query(connection: Connection, query: str, query_name: str):
    """Ejecuta una consulta y muestra los resultados"""
    print(f"\n{Colors.HEADER}{'='*80}{Colors.ENDC}")
    print(f"{Colors.BOLD}{Colors.OKCYAN}📊 {query_name}{Colors.ENDC}")
    print(f"{Colors.HEADER}{'='*80}{Colors.ENDC}\n")
    
    try:
        cursor = connection.cursor()
        cursor.execute(query)
        
        # Obtener nombres de columnas
        columns = [desc[0] for desc in cursor.description]
        
        # Obtener resultados
        results = cursor.fetchall()
        
        if not results:
            print(f"{Colors.WARNING}⚠️  No se encontraron resultados{Colors.ENDC}\n")
            return
        
        # Mostrar encabezados
        print(f"{Colors.BOLD}{' | '.join(str(col).ljust(20) for col in columns)}{Colors.ENDC}")
        print(f"{'-' * 80}")
        
        # Mostrar resultados
        for row in results:
            row_str = ' | '.join(str(val).ljust(20) if val is not None else 'NULL'.ljust(20) for val in row)
            print(row_str)
        
        print(f"\n{Colors.OKGREEN}✅ Total de filas: {len(results)}{Colors.ENDC}\n")
        
        cursor.close()
        
    except Exception as e:
        print(f"{Colors.FAIL}❌ Error al ejecutar la consulta: {str(e)}{Colors.ENDC}\n")
        raise

def main():
    """Función principal"""
    print(f"{Colors.BOLD}{Colors.HEADER}")
    print("="*80)
    print("🔍 VERIFICACIÓN DE COMPORTAMIENTO FREEMIUM")
    print("="*80)
    print(f"{Colors.ENDC}")
    
    # Cargar configuración de dbt
    print(f"{Colors.OKBLUE}📋 Cargando configuración de dbt...{Colors.ENDC}")
    config = load_dbt_profile()
    
    if not config['access_token']:
        print(f"{Colors.FAIL}❌ No se encontró el token de acceso. Configura DBT_TOKEN o DATABRICKS_TOKEN{Colors.ENDC}")
        sys.exit(1)
    
    print(f"{Colors.OKGREEN}✅ Configuración cargada{Colors.ENDC}")
    print(f"   Host: {config['server_hostname']}")
    print(f"   Catalog: {config['catalog']}")
    print(f"   Schema: {config['schema']}")
    
    # Leer el archivo SQL
    sql_file = Path(__file__).parent / "VERIFICACION_FREEMIUM.sql"
    if not sql_file.exists():
        print(f"{Colors.FAIL}❌ No se encontró el archivo VERIFICACION_FREEMIUM.sql{Colors.ENDC}")
        sys.exit(1)
    
    with open(sql_file, 'r') as f:
        sql_content = f.read()
    
    # Separar las consultas: buscar líneas que dicen "-- CONSULTA X:"
    import re
    
    lines = sql_content.split('\n')
    queries = []
    current_query = []
    current_name = None
    in_query = False
    
    for i, line in enumerate(lines):
        # Detectar inicio de consulta
        if re.match(r'--\s*CONSULTA\s+(\d+):\s*(.+)', line, re.IGNORECASE):
            # Guardar consulta anterior
            if current_query and current_name:
                query_sql = '\n'.join(current_query).strip()
                if query_sql:
                    queries.append({
                        'name': current_name,
                        'sql': query_sql
                    })
            
            # Extraer número y nombre de la nueva consulta
            match = re.match(r'--\s*CONSULTA\s+(\d+):\s*(.+)', line, re.IGNORECASE)
            if match:
                query_num = match.group(1)
                query_name = match.group(2).strip()
                current_name = f"{query_num}. {query_name}"
                current_query = []
                in_query = False  # Esperar a que termine el header de comentarios
            continue
        
        # Si estamos en una consulta, agregar líneas (saltar headers de comentarios)
        if current_name:
            # Saltar líneas de comentarios y separadores al inicio
            if not in_query:
                if line.strip().startswith('--') or line.strip().startswith('=') or not line.strip():
                    continue
                in_query = True
            
            # Agregar línea a la consulta
            if in_query:
                current_query.append(line)
    
    # Agregar última consulta
    if current_query and current_name:
        query_sql = '\n'.join(current_query).strip()
        if query_sql:
            queries.append({
                'name': current_name,
                'sql': query_sql
            })
    
    print(f"\n{Colors.OKGREEN}✅ Se encontraron {len(queries)} consultas{Colors.ENDC}\n")
    
    # Conectar a Databricks
    print(f"{Colors.OKBLUE}🔌 Conectando a Databricks...{Colors.ENDC}")
    try:
        connection = sql.connect(
            server_hostname=config['server_hostname'],
            http_path=config['http_path'],
            access_token=config['access_token']
        )
        print(f"{Colors.OKGREEN}✅ Conectado exitosamente{Colors.ENDC}\n")
    except Exception as e:
        print(f"{Colors.FAIL}❌ Error al conectar: {str(e)}{Colors.ENDC}")
        sys.exit(1)
    
    # Ejecutar cada consulta
    try:
        for i, query_info in enumerate(queries, 1):
            query_name = f"{i}. {query_info['name']}"
            execute_query(connection, query_info['sql'], query_name)
    finally:
        connection.close()
        print(f"{Colors.OKGREEN}✅ Conexión cerrada{Colors.ENDC}")

if __name__ == "__main__":
    main()

