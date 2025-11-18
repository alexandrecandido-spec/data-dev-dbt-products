🚀 **Nuevos modelos de onboarding en producción**

Hola equipo! 👋

Los tres modelos de métricas de configuración de onboarding ya están en producción y disponibles para consumo desde mañana:

✅ **Modelos disponibles:**

1. **`s__product_marketing__layout__ref`** (PR #484)
   - Métricas de configuración de layout (banner, slider, colores)
   - Completo cuando la tienda tiene las 3 configuraciones

2. **`s__product_marketing__payments__ref`** (PR #485)
   - Métricas de configuración de métodos de pago
   - Completo en la primera ocurrencia del evento PaymentProviderRegistered

3. **`s__product_marketing__shipping__ref`** (PR #486)
   - Métricas de configuración de métodos de envío
   - Completo cuando la tienda activó un carrier con status activo

📊 **Características:**
- Materialización incremental (MERGE strategy)
- Ejecución diaria a las 7:00 AM
- Granularidad: una fila por tienda (`store_id`)
- Tests de calidad de datos incluidos
- Documentación técnica completa disponible

🔗 **Links:**
- PR #484: https://github.com/TiendaNube/data-dev-dbt-products/pull/484
- PR #485: https://github.com/TiendaNube/data-dev-dbt-products/pull/485
- PR #486: https://github.com/TiendaNube/data-dev-dbt-products/pull/486

📍 **Ubicación:**
- Catalog: `testing_marketing`
- Schema: `testing_marketing`
- Tablas: `s__product_marketing__layout__ref`, `s__product_marketing__payments__ref`, `s__product_marketing__shipping__ref`

📝 **Documentación:**
- Documentación técnica y funcional disponible en el repositorio
- Ejemplos de consultas incluidos en la documentación

Cualquier duda, avisen! 🙌


