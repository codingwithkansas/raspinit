# Constants
TEST_IMAGE_UBUNTU_XZ_URL="https://cdimage.ubuntu.com/releases/22.04/release/ubuntu-22.04.3-preinstalled-server-arm64+raspi.img.xz"
TEST_IMAGE_UBUNTU_XZ_LOCAL_FILENAME="ubuntu-22.04.3-preinstalled-server-arm64+raspi.img.xz"

# Utility Functions
function set_config_with_base_image_url {
    PROJECT_DIR="$1"
    OUTPUT_FILENAME="$2"
    BASE_IMAGE_URL="$3"
    echo "Preparing config.json"
    jq -n --arg output_filename "$OUTPUT_FILENAME" \
          --arg base_image_url "$BASE_IMAGE_URL" \
            '{output_filename: $output_filename, base_image_url: $base_image_url}' > "$PROJECT_DIR/config.json"
    cat "$PROJECT_DIR/config.json"
}
function set_config_with_base_image {
    PROJECT_DIR="$1"
    OUTPUT_FILENAME="$2"
    BASE_IMAGE="$3"
    echo "Preparing config.json"
    jq -n --arg output_filename "$OUTPUT_FILENAME" \
          --arg base_image "$BASE_IMAGE" \
            '{output_filename: $output_filename, base_image: $base_image}' > "$PROJECT_DIR/config.json"
    cat "$PROJECT_DIR/config.json" | sed 's/^/    /'
}
function assert_fail {
    MSG="$1"
    echo "Assertion failed: $MSG"
    exit 1
}
function assert_pass {
    MSG="$1"
    echo "Assertion passed: $MSG"
}
function assert_output_image {
    PROJECT_DIR="$1"
    EXPECTED_IMAGE_NAME="$2"
    if [[ ! -f "$PROJECT_DIR/dist/$EXPECTED_IMAGE_NAME.img" ]];
    then
        assert_fail "Output image with expected name '$EXPECTED_IMAGE_NAME.img' does not exist."
    else
        assert_pass "Output image with expected name '$EXPECTED_IMAGE_NAME.img' exists."
    fi
}
function fail {
    TEST_CASE_NAME="$1"
    echo "Test execution failure: Test case '$TEST_CASE_NAME' failed"
    exit 1
}

# Test Helpers
function do_before {
    PROJECT_DIR="$1"

    # Preserve original config.json
    if [[ -f "$PROJECT_DIR/config.json" ]];
    then
        cp "$PROJECT_DIR/config.json" "$PROJECT_DIR/config.original.json"
    fi

    if [[ ! -f "$PROJECT_DIR/$TEST_IMAGE_UBUNTU_XZ_LOCAL_FILENAME" ]];
    then
        echo "Downloading cached image '$TEST_IMAGE_UBUNTU_XZ_LOCAL_FILENAME' for test."
        curl --output "$PROJECT_DIR/$TEST_IMAGE_UBUNTU_XZ_LOCAL_FILENAME" "$TEST_IMAGE_UBUNTU_XZ_URL"
    else
        echo "Cached image '$TEST_IMAGE_UBUNTU_XZ_LOCAL_FILENAME' for test has already been downloaded."
    fi
}
function do_after {
    PROJECT_DIR="$1"
    
    # Replace original config.json
    if [[ -f "$PROJECT_DIR/config.original.json" ]];
    then
        mv "$PROJECT_DIR/config.original.json" "$PROJECT_DIR/config.json"
    fi

    rm -rf "$PROJECT_DIR/dist"
    rm "$PROJECT_DIR/$TEST_IMAGE_UBUNTU_XZ_LOCAL_FILENAME"
}

# Test Cases
function test_case_simple_build_with_img_xz_url {
    PROJECT_DIR="$1"
    echo "Running Test case 'test_case_simple_build_with_img_xz_url'"

    set_config_with_base_image_url "$PROJECT_DIR" "test-output_filename" "$TEST_IMAGE_UBUNTU_XZ_URL"
    make build
    assert_output_image "$PROJECT_DIR" "test-output_filename"
}
function test_case_simple_build_with_img_xz_file {
    PROJECT_DIR="$1"
    echo "Running Test case 'test_case_simple_build_with_img_xz_file'"

    set_config_with_base_image "$PROJECT_DIR" "test-output_filename" "$TEST_IMAGE_UBUNTU_XZ_LOCAL_FILENAME"
    make build
    assert_output_image "$PROJECT_DIR" "test-output_filename"
}
function test_case_clean {
    PROJECT_DIR="$1"
    echo "Running Test case 'test_case_clean'"

    make clean
    if [[ -d "$PROJECT_DIR/dist" ]];
    then
        assert_fail "Build directory '$PROJECT_DIR/dist' exists, when it was not expected."
    else
        assert_pass "Build directory '$PROJECT_DIR/dist' does not exist."
    fi
}

# Test Entrypoint(s)
function run_all_tests {
    PROJECT_DIR="$1"

    echo "Running Before Scripts"
    do_before "$PROJECT_DIR"

    # Start test cases
    echo "Running Test Cases"
    test_case_simple_build_with_img_xz_file "$PROJECT_DIR"
    test_case_clean "$PROJECT_DIR"
    test_case_simple_build_with_img_xz_url "$PROJECT_DIR"
    # End test cases

    echo "Running After Scripts"
    do_after "$PROJECT_DIR"

    echo "Test execution completed successfully."
}