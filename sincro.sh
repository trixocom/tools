#!/bin/bash

# Solicitar rutas
read -p "Ruta LOCAL a sincronizar: " origen
read -p "Ruta REMOTA (usuario@server:ruta): " destino

# Validaciones básicas
if [ ! -d "$origen" ]; then
    echo "❌ Error: Directorio local no existe"
    exit 1
fi

if ! ssh "${destino%%:*}" "test -d ${destino#*:}" 2>/dev/null; then
    echo "⚠️ Advertencia: Directorio remoto no existe. Se creará durante la sincronización"
fi

# Configuración
echo -e "\n🚀 Iniciando sincronización:"
echo "   Origen:  $origen"
echo "   Destino: $destino"
echo -e "\n📡 Sincronizando archivos (esto puede tardar)..."

# Función para mostrar barra de progreso
progress_bar() {
    local total=$(find "$origen" -type f | wc -l)
    local count=0
    
    while read -r; do
        ((count++))
        percent=$((count * 100 / total))
        printf "\r["
        printf "%-${percent}s" | tr ' ' '#'
        printf "%$((100 - percent))s] %d%% (%d/%d)" "" $percent $count $total
    done
    echo
}

# Sincronización con progreso
rsync -ah --checksum --delete -e ssh \
    --info=progress2,name0,flist0 \
    --chown=root:root \
    "$origen/" "$destino/" 2>&1 | progress_bar

# Capturar resultado de rsync
rsync_exit=${PIPESTATUS[0]}

# Verificación final
if [ $rsync_exit -eq 0 ]; then
    echo -e "\n✅ Sincronización COMPLETADA con éxito"
    echo "   Todos los archivos son idénticos y con owner root:root"
else
    echo -e "\n❌ ERROR en sincronización (código: $rsync_exit)"
    echo "   Posibles causas:"
    echo "   - Problemas de conexión"
    echo "   - Permisos insuficientes"
    echo "   - Espacio en disco insuficiente"
    exit $rsync_exit
fi
