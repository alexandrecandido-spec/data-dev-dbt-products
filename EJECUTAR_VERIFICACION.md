# Ejecutar Verificación de Freemium

## 🚀 Ejecución Rápida

Desde la terminal, ejecuta:

```bash
cd data-dev-dbt-products
source ../venv/bin/activate  # Si estás en el directorio raíz
python ejecutar_verificacion_freemium.py
```

O si ya estás en el directorio del proyecto:

```bash
python ejecutar_verificacion_freemium.py
```

## 📋 Requisitos

1. **dbt configurado**: El script usa tu configuración de dbt (`~/.dbt/profiles.yml`)
2. **Token de acceso**: Necesitas tener configurado `DBT_TOKEN` o `DATABRICKS_TOKEN` en tu entorno, o en el archivo `profiles.yml`
3. **Python packages**: `databricks-sql` y `yaml` (ya instalados en tu venv)

## 🔍 Qué hace el script

1. Lee tu configuración de dbt (`~/.dbt/profiles.yml`)
2. Se conecta a Databricks usando las credenciales de dbt
3. Lee el archivo `VERIFICACION_FREEMIUM.sql`
4. Separa las 5 consultas automáticamente
5. Ejecuta cada consulta y muestra los resultados en la terminal

## 📊 Interpretación de Resultados

### Consultas 2 y 4 (Resúmenes) - Las más importantes

**Consulta 2: Resumen de Payments**
- `percentage_with_payment_events`: Si es **> 90%** = ✅ Funciona bien
- Si es **< 50%** = ❌ Hay problema

**Consulta 4: Resumen de Shipping**
- `percentage_with_active_carriers`: Si es **> 90%** = ✅ Funciona bien
- Si es **< 50%** = ❌ Hay problema

### Consultas 1 y 3 (Detalles)

Muestran tiendas individuales para análisis detallado. Revisa:
- `has_payment_event` / `has_active_carrier`: 1 = tiene, 0 = no tiene
- `days_between_store_creation_and_first_*`: Debería ser 0 o muy bajo si funciona automáticamente

## ⚠️ Troubleshooting

### Error: "No se encontró el archivo de perfiles de dbt"
```bash
# Configura dbt primero
cd nubeproduct
dbt debug
```

### Error: "No se encontró el token de acceso"
```bash
# Exporta el token
export DBT_TOKEN="tu_token_aqui"
# O
export DATABRICKS_TOKEN="tu_token_aqui"
```

### Error de conexión
Verifica que:
- Tu token sea válido
- Tengas acceso a Databricks
- El warehouse esté activo

## 📝 Notas

- El script muestra los resultados directamente en la terminal
- Si quieres guardar los resultados, puedes redirigir la salida: `python ejecutar_verificacion_freemium.py > resultados.txt`
- Las consultas se ejecutan secuencialmente (una por una)

