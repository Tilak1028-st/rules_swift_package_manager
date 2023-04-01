"""Tests for `bazel_apple_platforms` module."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:bazel_apple_platforms.bzl", "bazel_apple_platforms")

def _for_framework_test(ctx):
    env = unittest.begin(ctx)

    tests = [
        struct(
            msg = "all platforms",
            framework = "Foundation",
            exp = [
                "@rules_swift_package_manager//config_settings/spm/platform:ios",
                "@rules_swift_package_manager//config_settings/spm/platform:macos",
                "@rules_swift_package_manager//config_settings/spm/platform:tvos",
                "@rules_swift_package_manager//config_settings/spm/platform:watchos",
            ],
        ),
        struct(
            msg = "single platform",
            framework = "AppKit",
            exp = [
                "@rules_swift_package_manager//config_settings/spm/platform:macos",
            ],
        ),
        struct(
            msg = "several platformis",
            framework = "UIKit",
            exp = [
                "@rules_swift_package_manager//config_settings/spm/platform:ios",
                "@rules_swift_package_manager//config_settings/spm/platform:tvos",
                "@rules_swift_package_manager//config_settings/spm/platform:watchos",
            ],
        ),
    ]
    for t in tests:
        actual = bazel_apple_platforms.for_framework(t.framework)
        asserts.equals(env, t.exp, actual, t.msg)

    return unittest.end(env)

for_framework_test = unittest.make(_for_framework_test)

def bazel_apple_platforms_test_suite():
    return unittest.suite(
        "bazel_apple_platforms_tests",
        for_framework_test,
    )
