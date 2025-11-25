# 🎯 ACTUALIZACIONES DE CONFIGURACIÓN para coincidir con repo oficial

# ✅ Actualizar ORDER_FILTERS para usar caps del repo oficial:
ORDER_FILTERS = {
    'min_total_usd': 0,        # ✅ Repo oficial: 0 (era 1)
    'max_total_usd': 10000,    # ✅ Repo oficial: 10000 (era 50000)
    'excluded_storefronts': []  # ✅ Vacío porque hardcodeamos storefront <> 'permalink'
}

# ✅ Eliminar storefront_filter porque hardcodeamos el filtro:
# ANTES:
# if excluded_storefronts:
#     storefront_list = ", ".join(excluded_storefronts)
#     storefront_filter = f"AND o.storefront NOT IN ('{storefront_list}')"
# else:
#     storefront_filter = ""

# DESPUÉS: (remover este bloque completo)
storefront_filter = ""  # ✅ Vacío porque usamos hardcodeado: o.storefront <> 'permalink'

print("🎯 CONFIGURACIÓN ACTUALIZADA para coincidir con repo oficial:")
print(f"   - Cap USD: 0 - 10,000 (era 1 - 50,000)")
print(f"   - Storefront: hardcodeado <> 'permalink' (era configurable)")
print(f"   - Payment status: 'paid' solamente (era flexible)")
print(f"   - Status: <> 'cancelled' (era flexible)")
print("✅ Ahora los números van a COINCIDIR con el dashboard de la landing")


