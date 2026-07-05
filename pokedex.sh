#!/bin/bash

# ==============================================================================
# CONFIGURACIÓN Y COLORES RETRO (Estilo GBA Blanco/Negro)
# ==============================================================================
BG="\e[107m"
FG="\e[30m"
ACCENT="\e[1m"
RESET="\e[0m"

# Validar dependencias esenciales
for cmd in curl jq chafa; do
    if ! command -v $cmd &> /dev/null; then
        echo "Error: Se requiere '$cmd' instalado en el sistema."
        exit 1
    fi
done

# Directorio por defecto para guardar capturas
 DIR_CAPTURAS="$HOME/pokedex_capturas"

# ==============================================================================
# FUNCIONES DE TRADUCCIÓN LOCAL (Para máxima velocidad)
# ==============================================================================
traducir_tipo() {
    case "$1" in
        normal) echo "Normal";; fighting) echo "Lucha";; flying) echo "Volador";;
        poison) echo "Veneno";; ground) echo "Tierra";; rock) echo "Roca";;
        bug) echo "Bicho";; ghost) echo "Fantasma";; steel) echo "Acero";;
        fire) echo "Fuego";; water) echo "Agua";; grass) echo "Planta";;
        electric) echo "Eléctrico";; psychic) echo "Psíquico";; ice) echo "Hielo";;
        dragon) echo "Dragón";; dark) echo "Siniestro";; fairy) echo "Hada";;
        *) echo "Desconocido";;
    esac
}

traducir_region() {
    case "$1" in
        "generation-i")   echo "Kanto (1ª Gen)";;
        "generation-ii")  echo "Johto (2ª Gen)";;
        "generation-iii") echo "Hoenn (3ª Gen)";;
        "generation-iv")  echo "Sinnoh (4ª Gen)";;
        "generation-v")   echo "Teselia/Unova (5ª Gen)";;
        "generation-vi")  echo "Kalos (6ª Gen)";;
        "generation-vii") echo "Alola (7ª Gen)";;
        "generation-viii")echo "Galar (8ª Gen)";;
        "generation-ix")  echo "Paldea (9ª Gen)";;
        *) echo "Desconocida";;
    esac
}

# ==============================================================================
# VALIDACION E INSTALACION DE DEPENDENCIAS
# ==============================================================================

verificar_dependencias() {
    local dependencias=("curl" "jq" "chafa" "mpv")
    local faltantes=()

    # 1. Chequeo silencioso: verifica si los comandos existen en el sistema
    for cmd in "${dependencias[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            faltantes+=("$cmd")
        fi
    done

    # 2. Bloque de instalación: SOLO se ejecuta si la lista 'faltantes' NO está vacía
    if [ ${#faltantes[@]} -ne 0 ]; then
        clear
        echo -e "${BG}${FG} ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓ ${RESET}"
        printf "${BG}${FG} ┃  %-50s ┃ ${RESET}\n" "Instalando dependencias necesarias..."
        printf "${BG}${FG} ┃  %-50s ┃ ${RESET}\n" "Paquetes: ${faltantes[*]}"
        echo -e "${BG}${FG} ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛ ${RESET}"
        echo ""
        
        sudo apt-get update -qq
        # Se redirige la salida estándar para que la instalación de apt-get sea más silenciosa
        sudo apt-get install -y "${faltantes[@]}"
        
        clear
        echo -e "${BG}${FG} ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓ ${RESET}"
        printf "${BG}${FG} ┃  %-50s ┃ ${RESET}\n" "¡Todo listo! Iniciando Pokédex..."
        echo -e "${BG}${FG} ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛ ${RESET}"
        sleep 1.5
    fi
    
    # Si no falta ninguna dependencia, la función llega a este punto y termina
    # sin haber impreso ni ejecutado absolutamente nada en la terminal.
}

# ==============================================================================
# LÓGICA DE LA API Y RENDERIZADO DE FICHA
# ==============================================================================
buscar_pokemon() {
    local BUSQUEDA="$1"
    
    # Si no se le pasa ningún argumento, pide el nombre por pantalla
    if [[ -z "$BUSQUEDA" ]]; then
        clear
        echo -e "${BG}${FG} Introduce el nombre o ID del Pokémon: ${RESET}"
        read -r BUSQUEDA
    fi

    # Convertir a minúsculas para la API
    BUSQUEDA=$(echo "$BUSQUEDA" | tr '[:upper:]' '[:lower:]' | tr -d ' ')
    if [[ -z "$BUSQUEDA" ]]; then return; fi

    clear
    echo -e "\n Cargando datos desde la Base de Datos Celadon..."

    # 1. Petición Principal (Datos base)
    POKE_DATA=$(curl -s --max-time 5 "https://pokeapi.co/api/v2/pokemon/$BUSQUEDA")
    if [[ -z "$POKE_DATA" || "$POKE_DATA" == "Not Found" ]]; then
        echo -e "\n[!] Pokémon no encontrado. Verifica el nombre."
        read -rsn1 -p "Presiona cualquier tecla para continuar..."
        return
    fi

    # Obtener sprite o imagen
    ID=$(echo "$POKE_DATA" | jq -r '.id')
    SPRITE_URL=$(echo "$POKE_DATA" | jq -r '.sprites.front_default')
    
    # Obtener sonido o 'Cry'
    CRY_URL=$(echo "$POKE_DATA" | jq -r '.cries.latest // empty')
    
    # Formatear peso y altura
    ALTURA=$(echo "$POKE_DATA" | jq -r '.height' | awk '{printf "%.1f m", $1/10}')
    PESO=$(echo "$POKE_DATA" | jq -r '.weight' | awk '{printf "%.1f kg", $1/10}')

    # Traducir Tipos
    T1=$(echo "$POKE_DATA" | jq -r '.types[0].type.name')
    T2=$(echo "$POKE_DATA" | jq -r '.types[1].type.name // empty')
    TIPO_FINAL=$(traducir_tipo "$T1")
    if [[ -n "$T2" ]]; then TIPO_FINAL="$TIPO_FINAL / $(traducir_tipo "$T2")"; fi

    # 2. Petición de Especie
    SPECIES_URL=$(echo "$POKE_DATA" | jq -r '.species.url')
    SPECIES_DATA=$(curl -s "$SPECIES_URL")
    
    NOMBRE_ES=$(echo "$SPECIES_DATA" | jq -r '.names[] | select(.language.name=="es") | .name' | head -n1)
    [[ -z "$NOMBRE_ES" ]] && NOMBRE_ES=$(echo "$POKE_DATA" | jq -r '.name | upcase')
    
    GEN_RAW=$(echo "$SPECIES_DATA" | jq -r '.generation.name')
    REGION=$(traducir_region "$GEN_RAW")

    # 3. Cadena de Evolución
    EVO_URL=$(echo "$SPECIES_DATA" | jq -r '.evolution_chain.url')
    EVO_DATA=$(curl -s "$EVO_URL")
    CADENA_EVO=$(echo "$EVO_DATA" | jq -r '[.. | .species? | .name? | select(. != null)] | map((.[0:1] | ascii_upcase) + .[1:]) | join(" -> ")')

    # 4. Renderizado en Pantalla
    clear

    # Reproducir el sonido en segundo plano de forma silenciosa (&)
    if [[ -n "$CRY_URL" && "$CRY_URL" != "null" ]]; then
        mpv --no-video --really-quiet --volume=35 "$CRY_URL" > /dev/null 2>&1 &
    fi

    # Descargar y dibujar sprite
    if [[ "$SPRITE_URL" != "null" ]]; then
        curl -s "$SPRITE_URL" -o /tmp/pokesprite.png
        chafa --size=40x16 --colors=256 /tmp/pokesprite.png
        rm -f /tmp/pokesprite.png
    else
        echo -e "\n[ Sin Ilustración Disponible ]\n"
    fi

    echo -e "${BG}${FG} ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓ ${RESET}"
    printf "${BG}${FG} ┃  ${ACCENT}%-50s${RESET}${BG}${FG} ┃ ${RESET}\n" "INFO POKÉMON"
    echo -e "${BG}${FG} ┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫ ${RESET}"
    printf "${BG}${FG} ┃  %-50s ┃ ${RESET}\n" "• Nombre:  ${NOMBRE_ES^^} (#$ID)"
    printf "${BG}${FG} ┃  %-50s ┃ ${RESET}\n" "• Tipo:    $TIPO_FINAL"
    printf "${BG}${FG} ┃  %-50s ┃ ${RESET}\n" "• Región:  $REGION"
    printf "${BG}${FG} ┃  %-50s ┃ ${RESET}\n" "• Medidas: $ALTURA / $PESO"
    echo -e "${BG}${FG} ┃                                                    ┃ ${RESET}"
    echo -e "${BG}${FG} ┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫ ${RESET}"
    printf "${BG}${FG} ┃  ${ACCENT}%-50s${RESET}${BG}${FG} ┃ ${RESET}\n" "LÍNEA EVOLUTIVA"
    echo -e "${BG}${FG} ┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫ ${RESET}"
    printf "${BG}${FG} ┃  %-50s ┃ ${RESET}\n" "$CADENA_EVO"
    echo -e "${BG}${FG} ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛ ${RESET}"
    echo ""

    # ==============================================================================
    # SISTEMA DE CAPTURA (Exportación Markdown Zettelkasten)
    # ==============================================================================
    echo -e "${BG}${FG} [C] Capturar Pokémon  |  [Cualquier otra tecla] Regresar al Menú ${RESET}"
    read -rsn1 tecla

    if [[ "${tecla^^}" == "C" ]]; then
        # 1. Crear el directorio global si no existe
        mkdir -p "$DIR_CAPTURAS"
        
        # 2. Limpieza de variables para Tags (convierte a minúsculas y quita acentos)
        local TAG_REGION=$(echo "$REGION" | awk '{print tolower($1)}' | sed 'y/áéíóú/aeiou/')
        local TAG_TIPO=$(echo "$TIPO_FINAL" | sed 's/ \/ /-/g' | tr '[:upper:]' '[:lower:]' | sed 'y/áéíóú/aeiou/')
        
        # 3. Formatear enlaces bidireccionales de la línea evolutiva
        local EVO_WIKI="[[${CADENA_EVO// -> /]] -> [[}]]"
        
        local NOMBRE_CAPITALIZADO="${NOMBRE_ES^}"
        local ARCHIVO="$DIR_CAPTURAS/${NOMBRE_CAPITALIZADO}.md"
        
        # 4. Inyectar la estructura Markdown directamente en el archivo
        cat <<EOF > "$ARCHIVO"
---
aliases: ["${NOMBRE_ES^^}"]
tags:
  - pokemon/tipo/$TAG_TIPO
  - pokemon/region/$TAG_REGION
id: $ID
altura: $ALTURA
peso: $PESO
---

# $NOMBRE_CAPITALIZADO

![Sprite Oficial]($SPRITE_URL)

## Datos Biométricos
- **Tipo:** $TIPO_FINAL
- **Región:** $REGION
- **Medidas:** $ALTURA / $PESO

## Línea Evolutiva
$EVO_WIKI
EOF
        
        # Mensaje visual de confirmación
        echo -e "\n ${BG}${FG}${ACCENT} ¡${NOMBRE_CAPITALIZADO} registrado en la base de datos! ${RESET}"
        echo -e " ${BG}${FG} 💾 Archivo guardado en: $ARCHIVO ${RESET}"
        sleep 2.5
    fi
}

# ==============================================================================
# MENU INTERACTIVO PRINCIPAL
# ==============================================================================

filtrar_por_region() {
    local regiones=("Kanto" "Johto" "Hoenn" "Sinnoh" "Teselia" "Kalos" "Alola" "Galar" "Paldea" "Volver")
    local sel=0

    while true; do
        clear
        echo -e "${BG}${FG} ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓ ${RESET}"
        echo -e "${BG}${FG} ┃         SELECCIONA UNA REGIÓN       ┃ ${RESET}"
        echo -e "${BG}${FG} ┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫ ${RESET}"
        for i in "${!regiones[@]}"; do
            if [[ $i -eq $sel ]]; then
                printf "${BG}${FG} ┃  ▶ %-31s ┃ ${RESET}\n" "${regiones[$i]}"
            else
                printf "${BG}${FG} ┃    %-31s ┃ ${RESET}\n" "${regiones[$i]}"
            fi
        done
        echo -e "${BG}${FG} ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛ ${RESET}"

        read -rsn1 tecla
        if [[ $tecla == $'\e' ]]; then
            read -rsn2 tecla
            case "$tecla" in
                "[A") ((sel--)); if [[ $sel -lt 0 ]]; then sel=$((${#regiones[@]} - 1)); fi ;;
                "[B") ((sel++)); if [[ $sel -ge ${#regiones[@]} ]]; then sel=0; fi ;;
            esac
        elif [[ -z $tecla ]]; then
            if [[ "${regiones[$sel]}" == "Volver" ]]; then return; fi
            
            clear
            echo "Explorando la región de ${regiones[$sel]}..."
            local gen_id=$((sel + 1))
            local data=$(curl -s "https://pokeapi.co/api/v2/generation/$gen_id")
            
            echo -e "${BG}${FG} ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓ ${RESET}"
            printf "${BG}${FG} ┃  ${ACCENT}%-50s${RESET}${BG}${FG} ┃ ${RESET}\n" "POKÉMON DE LA REGIÓN: ${regiones[$sel]^^}"
            echo -e "${BG}${FG} ┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫ ${RESET}"
            
            # Extraer nombres, ordenar alfabéticamente y formatear en 3 columnas
            echo "$data" | jq -r '.pokemon_species[].name' | sort | xargs -n 3 | while read -r c1 c2 c3; do
                linea=$(printf "%-16s %-16s %-16s" "${c1^^}" "${c2^^}" "${c3^^}")
                printf "${BG}${FG} ┃  %-50s ┃ ${RESET}\n" "$linea"
            done
            
            echo -e "${BG}${FG} ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛ ${RESET}"
            echo ""
            echo -e "${BG}${FG} Escribe un nombre para inspeccionarlo (o Enter para Volver): ${RESET}"
            read -r poke_elegido
            if [[ -n "$poke_elegido" ]]; then
                buscar_pokemon "$poke_elegido"
            fi
            return
        fi
    done
}

filtrar_por_tipo() {
    local tipos_es=("Normal" "Lucha" "Volador" "Veneno" "Tierra" "Roca" "Bicho" "Fantasma" "Acero" "Fuego" "Agua" "Planta" "Eléctrico" "Psíquico" "Hielo" "Dragón" "Siniestro" "Hada" "Volver")
    local tipos_en=("normal" "fighting" "flying" "poison" "ground" "rock" "bug" "ghost" "steel" "fire" "water" "grass" "electric" "psychic" "ice" "dragon" "dark" "fairy")
    local sel=0

    while true; do
        clear
        echo -e "${BG}${FG} ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓ ${RESET}"
        echo -e "${BG}${FG} ┃          SELECCIONA UN TIPO         ┃ ${RESET}"
        echo -e "${BG}${FG} ┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫ ${RESET}"
        for i in "${!tipos_es[@]}"; do
            if [[ $i -eq $sel ]]; then
                printf "${BG}${FG} ┃  ▶ %-31s ┃ ${RESET}\n" "${tipos_es[$i]}"
            else
                printf "${BG}${FG} ┃    %-31s ┃ ${RESET}\n" "${tipos_es[$i]}"
            fi
        done
        echo -e "${BG}${FG} ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛ ${RESET}"

        read -rsn1 tecla
        if [[ $tecla == $'\e' ]]; then
            read -rsn2 tecla
            case "$tecla" in
                "[A") ((sel--)); if [[ $sel -lt 0 ]]; then sel=$((${#tipos_es[@]} - 1)); fi ;;
                "[B") ((sel++)); if [[ $sel -ge ${#tipos_es[@]} ]]; then sel=0; fi ;;
            esac
        elif [[ -z $tecla ]]; then
            if [[ "${tipos_es[$sel]}" == "Volver" ]]; then return; fi
            
            clear
            echo "Descargando registros de tipo ${tipos_es[$sel]}..."
            local tipo_id="${tipos_en[$sel]}"
            local data=$(curl -s "https://pokeapi.co/api/v2/type/$tipo_id")
            
            echo -e "${BG}${FG} ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓ ${RESET}"
            printf "${BG}${FG} ┃  ${ACCENT}%-50s${RESET}${BG}${FG} ┃ ${RESET}\n" "POKÉMON TIPO: ${tipos_es[$sel]^^}"
            echo -e "${BG}${FG} ┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫ ${RESET}"
            
            # Extraer nombres (la estructura JSON de tipos es distinta a la de regiones)
            echo "$data" | jq -r '.pokemon[].pokemon.name' | sort | xargs -n 3 | while read -r c1 c2 c3; do
                linea=$(printf "%-16s %-16s %-16s" "${c1^^}" "${c2^^}" "${c3^^}")
                printf "${BG}${FG} ┃  %-50s ┃ ${RESET}\n" "$linea"
            done
            
            echo -e "${BG}${FG} ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛ ${RESET}"
            echo ""
            echo -e "${BG}${FG} Escribe un nombre para inspeccionarlo (o Enter para Volver): ${RESET}"
            read -r poke_elegido
            if [[ -n "$poke_elegido" ]]; then
                buscar_pokemon "$poke_elegido"
            fi
            return
        fi
    done
}

OPCIONES=("Buscar Pokémon" "Filtrar por región" "Filtrar por tipo" "Acerca de" "Salir")
SELECCION=0

dibujar_menu() {
    clear
    echo -e "${BG}${FG} ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓ ${RESET}"
    echo -e "${BG}${FG} ┃            POKÉDEX BASH             ┃ ${RESET}"
    echo -e "${BG}${FG} ┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫ ${RESET}"
    for i in "${!OPCIONES[@]}"; do
        if [[ $i -eq $SELECCION ]]; then
            printf "${BG}${FG} ┃  ▶ %-31s ┃ ${RESET}\n" "${OPCIONES[$i]}"
        else
            printf "${BG}${FG} ┃    %-31s ┃ ${RESET}\n" "${OPCIONES[$i]}"
        fi
    done
    echo -e "${BG}${FG} ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛ ${RESET}"
}

while true; do
    dibujar_menu
    read -rsn1 tecla
    if [[ $tecla == $'\e' ]]; then
        read -rsn2 tecla
        case "$tecla" in
            "[A") ((SELECCION--))
                 if [[ $SELECCION -lt 0 ]]; then SELECCION=$((${#OPCIONES[@]} - 1)); fi ;;
            "[B") ((SELECCION++))
                 if [[ $SELECCION -ge ${#OPCIONES[@]} ]]; then SELECCION=0; fi ;;
        esac
    elif [[ -z $tecla ]]; then
        case $SELECCION in
            0) buscar_pokemon ;;
            1) filtrar_por_region ;;
            2) filtrar_por_tipo ;;
            3) clear
               echo "PokédexEngine v1.1 - Desarrollado por s0rcen."
               echo "Usa PokeAPI y Chafa para gráficos de terminal."
               read -rsn1 -p "Presiona cualquier tecla para volver..." ;;
            4) clear; echo "¡Adios, Entrenador!"; exit 0 ;;
        esac
    fi
done
