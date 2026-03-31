'use strict';

function assert_eq(actual, expected, msg) {
    if (actual === expected) return true;
    return sprintf("%s: expected %J, got %J", msg || "assert_eq", expected, actual);
}

function assert_truthy(val, msg) {
    if (val != null && val != false) return true;
    return sprintf("%s: expected truthy, got %J", msg || "assert_truthy", val);
}

function assert_null(val, msg) {
    if (val == null) return true;
    return sprintf("%s: expected null, got %J", msg || "assert_null", val);
}

function assert_not_null(val, msg) {
    if (val != null) return true;
    return sprintf("%s: expected non-null", msg || "assert_not_null");
}

function assert_false(val, msg) {
    if (val == false || val == null) return true;
    return sprintf("%s: expected false/null, got %J", msg || "assert_false", val);
}

function assert_match(str, pattern, msg) {
    if (type(str) != "string") return sprintf("%s: not a string: %J", msg || "assert_match", str);
    if (match(str, pattern)) return true;
    return sprintf("%s: %J did not match pattern", msg || "assert_match", str);
}

function assert_contains(str, substr, msg) {
    if (type(str) != "string") return sprintf("%s: not a string: %J", msg || "assert_contains", str);
    if (index(str, substr) >= 0) return true;
    return sprintf("%s: %J does not contain %J", msg || "assert_contains", str, substr);
}

function assert_gt(actual, than, msg) {
    if (actual > than) return true;
    return sprintf("%s: expected > %J, got %J", msg || "assert_gt", than, actual);
}

function assert_is_function(val, msg) {
    if (type(val) == "function") return true;
    return sprintf("%s: expected function, got %s", msg || "assert_is_function", type(val));
}

export {
    assert_eq, assert_truthy, assert_null, assert_not_null, assert_false,
    assert_match, assert_contains, assert_gt, assert_is_function
};
