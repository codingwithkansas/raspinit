# Constants
BUILD_CONTEXT_DOCKER_IMAGE="raspinit-builder-ctx"

# Utility Functions
function get_build_ctx_docker_imagetag {
    PWD="$1"
    TAG=`cat "$PWD/Dockerfile" | grep "ENV" | grep "VERSION" | sed 's/ENV VERSION=//' | tr -d '\"'`
    printf "$BUILD_CONTEXT_DOCKER_IMAGE-$TAG"
}
function ctrl_ansi_bold {
    printf '%s%s%s' $(printf '\033[1m') "$1" $(printf '\033[0m')
}
function ctrl_ansi_magenta {
    printf '%s%s%s' $(printf '\033[35m') "$1" $(printf '\033[0m')
}
function ctrl_ansi_green {
    printf '%s%s%s' $(printf '\033[32m') "$1" $(printf '\033[0m')
}
function ctrl_ansi_red {
    printf '%s%s%s' $(printf '\033[31m') "$1" $(printf '\033[0m')
}
function log {
    MSG="$1"
    for var in "$@"
    do
        if [[ "$(type -t $var)" == "function" ]];
        then
            MSG=$("$var" "$MSG")
        fi
    done
    printf "$MSG\n"
}
function log_header {
    log "$1" ctrl_ansi_bold ctrl_ansi_magenta
}
function log_indent {
    INDENT="$2"
    if [[ -z "$INDENT" ]];
    then
        INDENT=" >  "
    fi
    MSG=`echo -e $1 | sed "s/^/$INDENT/"`
    echo -e "$MSG"
}

# Helper Functions
function mount_root_partition {
    FDISK="$(fdisk -l /src/dist/rpi.img)"
    FILE="$(file -s /src/dist/rpi.img)"
    START_SECTOR=`file -s /src/dist/rpi.img | cut -d "partition" -f 4 | tr , '\n' | grep "startsector" | tr -d " startsector "`
    OFFSET="$(($START_SECTOR * 512))"
   
    log_indent "Mounting 'root' partition [mount=/src/dist/tmp.mnt--data, image=/src/dist/rpi.img, offset=$OFFSET]"
    mkdir /src/dist/tmp.mnt--data || echo "Directory Exists"
    mount /src/dist/rpi.img -o "loop,offset=$OFFSET" /src/dist/tmp.mnt--data
    log_indent "|____ $(df -h | grep '/src/dist/tmp.mnt--data')"
}
function unmount_root_partition {
    log_indent "Unmounting 'root' partition at /src/dist/tmp.mnt--data\n\n"
    umount /src/dist/tmp.mnt--data
    rm -rf /src/dist/tmp.mnt--data
}
function mount_boot_partition {
    FDISK="$(fdisk -l /src/dist/rpi.img)"
    FILE="$(file -s /src/dist/rpi.img)"
    START_SECTOR=`file -s /src/dist/rpi.img | cut -d "partition" -f 3 | tr , '\n' | grep "startsector" | tr -d " startsector "`
    OFFSET="$(($START_SECTOR * 512))"

    log_indent "Mounting 'boot' partition [mount=/src/dist/tmp.mnt--boot, image=/src/dist/rpi.img, offset=$OFFSET]"
    mkdir /src/dist/tmp.mnt--boot  || echo "Directory Exists"
    mount /src/dist/rpi.img -o "loop,offset=$OFFSET" /src/dist/tmp.mnt--boot
    log_indent "|____ $(df -h | grep '/src/dist/tmp.mnt--boot')"
}
function unmount_boot_partition {
    log_indent "Unmounting 'boot' partition at /src/dist/tmp.mnt--boot\n\n"
    umount /src/dist/tmp.mnt--boot 
    rm -rf /src/dist/tmp.mnt--boot
}

# Make Targets
function build_image {
    IMAGE_ID="$(uuidgen)"
    OUTPUT_FILENAME="$(cat $PWD/config.json | jq '.output_filename' | tr -d '\"')"
    log_header "Building image '$OUTPUT_FILENAME' with image ID: $IMAGE_ID"

    mount_boot_partition
    BOOT_TEMPLATE_COUNT=`rsync -av --progress --dry-run --stats /src/templates/boot-partition/* /src/dist/tmp.mnt--boot | \
        fgrep 'Number of files' | \
        cut -d' ' -f4 | \
        tr -d ,`
    cp -R /src/templates/boot-partition/* "/src/dist/tmp.mnt--boot/"
    log_indent "$(log "Added '$BOOT_TEMPLATE_COUNT' template files to 'boot' partition" ctrl_ansi_bold ctrl_ansi_green)"
    unmount_boot_partition

    mount_root_partition
    ROOT_TEMPLATE_COUNT=`rsync -av --progress --dry-run --stats /src/templates/root-partition/* /src/dist/tmp.mnt--data | \
        fgrep 'Number of files' | \
        cut -d' ' -f4 | \
        tr -d ,`
    cp -R /src/templates/root-partition/* "/src/dist/tmp.mnt--data/"
    log_indent "$(log "Added '$ROOT_TEMPLATE_COUNT' template files to 'root' partition" ctrl_ansi_bold ctrl_ansi_green)"
    jq -n --arg build_id "$IMAGE_ID" \
          --arg filename "$OUTPUT_FILENAME" \
          --arg build_date "$(date)" \
          '{build_id: $build_id, build_date: $build_date, filename: $filename}' > /src/dist/tmp.mnt--data/raspi-cloud-init.json
    log_indent "Added '/raspi-cloud-init.json' file with build encoding$(cat /src/dist/tmp.mnt--data/raspi-cloud-init.json | sed 's/^/\\n  /')"
    unmount_root_partition

    mv /src/dist/rpi.img "/src/dist/$OUTPUT_FILENAME.img"
    log "Completed writing image to output file: /src/dist/$OUTPUT_FILENAME.img" ctrl_ansi_bold ctrl_ansi_green
}
function fetch_source_image {
    PWD="$1"
    BUILD_CONTEXT_DOCKER_IMAGETAG="$(get_build_ctx_docker_imagetag "$PWD")"
    log_header "Validating source image"
    RPI_IMAGE_FILE="$(cat $PWD/config.json | jq '.base_image' | tr -d '\"')"
    RPI_IMAGE_URL="$(cat $PWD/config.json | jq '.base_image_url' | tr -d '\"')"
    log_indent "RPI_IMAGE_FILE:  $RPI_IMAGE_FILE"
    log_indent "RPI_IMAGE_URL:   $RPI_IMAGE_URL"

    if [[ -z "$RPI_IMAGE_FILE" ]] || [[ "$RPI_IMAGE_FILE" == "null" ]];
    then
        if [[ -z "$RPI_IMAGE_URL" ]] || [[ "$RPI_IMAGE_URL" == "null" ]];
        then
            log_indent "$(log "No 'base_image' or 'base_image_url' properties given. Unable to resolve base image." ctrl_ansi_red)"
            exit 1
        else
            if [[ "$PWD/$RPI_IMAGE_URL" == *.xz ]];
            then
                log_indent "$(log "Compressed ImageURL is defined and will be retrieved" ctrl_ansi_green)"
                mkdir "$PWD/dist" || echo "Build 'dist' directory already exists"
                RPI_IMAGE_URL="$(cat $PWD/config.json | jq '.base_image_url' | tr -d '\"')"
                curl --output "$PWD/dist/rpi.img.xz" "$RPI_IMAGE_URL"
                docker run --entrypoint /bin/sh -it -v "$PWD:/src" "$BUILD_CONTEXT_DOCKER_IMAGETAG" -c "xz -d -v /src/dist/rpi.img.xz"
            else
                log_indent "$(log "ImageURL is defined and will be retrieved" ctrl_ansi_green)"
                mkdir "$PWD/dist" || echo "Build 'dist' directory already exists"
                RPI_IMAGE_URL="$(cat $PWD/config.json | jq '.base_image_url' | tr -d '\"')"
                curl --output "$PWD/dist/rpi.img" "$RPI_IMAGE_URL"
            fi
        fi
    else
        if [ -f "$PWD/$RPI_IMAGE_FILE" ];
        then
            if [[ "$PWD/$RPI_IMAGE_FILE" == *.xz ]];
            then
                log_indent "$(log "Compressed image is defined and exists" ctrl_ansi_green)"
                mkdir "$PWD/dist" || echo "Build 'dist' directory already exists"
                cp "$PWD/$RPI_IMAGE_FILE" "$PWD/dist/rpi.img.xz"
                docker run --entrypoint /bin/sh -it -v "$PWD:/src" "$BUILD_CONTEXT_DOCKER_IMAGETAG" -c "xz -d -v /src/dist/rpi.img.xz"
            else
                log_indent "$(log "Image is defined and exists" ctrl_ansi_green)"
                mkdir "$PWD/dist" || echo "Build 'dist' directory already exists"
                cp "$PWD/$RPI_IMAGE_FILE" "$PWD/dist/rpi.img"
            fi
        else
            log_indent "$(log "Image file is defined but does not exist." ctrl_ansi_red)"
            exit 1
        fi
    fi
    echo ""
}
function build {
    PWD="$1"
    BUILD_CONTEXT_DOCKER_IMAGETAG="$(get_build_ctx_docker_imagetag "$PWD")"
    log_header "Initializing docker build environment"
    if [[ "$(docker images -q "$BUILD_CONTEXT_DOCKER_IMAGETAG" 2> /dev/null)" == "" ]]; then
        log_indent "Docker image for builder '"$BUILD_CONTEXT_DOCKER_IMAGETAG"' does not exist. Creating now."
        docker build -t "$BUILD_CONTEXT_DOCKER_IMAGETAG" .  > /dev/null
    fi
	docker run --privileged --user=root --entrypoint /bin/sh -it -v "$PWD:/src" "$BUILD_CONTEXT_DOCKER_IMAGETAG" -c "make DOCKER_CTX_build_image"
    echo ""
}
function clean {
    PWD="$1"
    CLEAN_ACTION="$2"
    BUILD_CONTEXT_DOCKER_IMAGETAG="$(get_build_ctx_docker_imagetag "$PWD")"
    log_header "Cleaning previous builds located at $PWD/dist"
	rm -rf "$PWD/dist" > /dev/null
    if [[ "$CLEAN_ACTION" == "all" ]];
    then
        log_indent "Removing cached build context container image '"$BUILD_CONTEXT_DOCKER_IMAGETAG"'"
        docker image rm "$BUILD_CONTEXT_DOCKER_IMAGETAG" --force > /dev/null
    fi
}