#!/bin/bash

# Solicitar rutas de origen y destino
read -p "Introduce la ruta LOCAL del directorio a sincronizar: " origen
read -p "Introduce la ruta REMOTA (usuario@servidor:ruta): " destino

# Verificar existencia de directorio local
if [ ! -d "$origen" ]; then
    echo "❌ ERROR: El directorio local '$origen' no existe"
    exit 1
fi

# Asegurar formato correcto para rsync
[[ "$origen" != */ ]] && origen="$origen/"
[[ "$destino" != */ ]] && destino="$destino/"

echo -e "\n🚀 Iniciando sincronización..."
echo "   Origen:  $origen"
echo "   Destino: $destino"

# Paso 1: Sincronización con verificación de checksums
rsync -ahv --checksum --delete --stats -e ssh "$origen" "$destino"

# Verificar resultado de rsync
if [ $? -ne 0 ]; then
    echo -e "\n❌ ERROR CRÍTICO: Fallo durante la transferencia"
    exit 1
else
    echo -e "\n✅ Transferencia completada sin errores"
fi

# Paso 2: Verificación de integridad
echo -e "\n🔍 Iniciando verificación de integridad..."

# Crear archivos temporales
tmp_local=$(mktemp)
tmp_remote=$(mktemp)

# Generar checksums locales
find "$origen" -type f -exec md5sum {} + | sort > "$tmp_local"

# Generar checksums remotos
ssh "${destino%%:*}" "cd ${destino#*:} && find . -type f -exec md5sum {} + | sort" > "$tmp_remote"

# Comparar resultados
diff_result=$(diff -y --suppress-common-lines "$tmp_local" "$tmp_remote")
diferencias=$(echo "$diff_result" | wc -l)

if [ "$diferencias" -gt 0 ]; then
    echo -e "\n❌ ERROR: Se detectaron $diferencias diferencias:\n"
    echo "================================================="
    echo "DIFERENCIAS ENCONTRADAS:"
    echo "================================================="
    echo "LOCAL (Origen)                  | REMOTO (Destino)"
    echo "-------------------------------------------------"
    echo "$diff_result"
    echo "================================================="
else
    echo -e "\n✅ Verificación exitosa: Los directorios son idénticos"
fi

# Limpieza
rm -f "$tmp_local" "$tmp_remote"
