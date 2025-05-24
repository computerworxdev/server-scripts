. messages.sh

number_of_parameters() {
    local caller="${FUNCNAME[1]}"
    local expected="$1"
    local actual="$2"
    local help_text="$3"

    if [ "$actual" -ne "$expected" ]; then
        alert "error: $caller expected $expected parameters, but got $actual."
        echo "$help_text"
        return 1
    fi
}

test_number_of_parameters() {
    test_func() {
        local help_text="Usage: test_func <param1> <param2>"
        number_of_parameters 2 $# "$help_text" || return 1
        success "number of parameters correct: $1, $2"
    }

    echo "Test 1: No parameters (should fail)"
    test_func

    echo "Test 2: One parameter (should fail)"
    test_func "only_one"

    echo "Test 3: Two parameters (should pass)"
    test_func "first" "second"

    echo "Test 4: Three parameters (should fail)"
    test_func "one" "two" "extra"
}
