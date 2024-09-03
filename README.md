# Gazelle Plugin for Swift and Swift Package Rules for Bazel

[![Build](https://github.com/cgrindel/rules_swift_package_manager/actions/workflows/ci.yml/badge.svg?event=schedule)](https://github.com/cgrindel/rules_swift_package_manager/actions/workflows/ci.yml)

This repository contains a [Gazelle plugin] and Bazel repository rules that can be used to download,
build, and consume Swift packages. The rules in this repository build the external Swift packages
using [rules_swift] and native C/C++ rulesets making the Swift package products and targets
available as Bazel targets.

This repository is designed to fully replace [rules_spm] and provide utilities to ease Swift
development inside a Bazel workspace.

## Table of Contents

<!-- MARKDOWN TOC: BEGIN -->
* [Documentation](#documentation)
* [Prerequisites](#prerequisites)
  * [Mac OS](#mac-os)
  * [Linux](#linux)
* [Quickstart](#quickstart)
  * [1. Enable bzlmod](#1-enable-bzlmod)
  * [2. Configure your `MODULE.bazel` to use rules_swift_package_manager.](#2-configure-your-modulebazel-to-use-rules_swift_package_manager)
    * [(Optional) Enable `swift_deps_info` generation for the Gazelle plugin](#optional-enable-swift_deps_info-generation-for-the-gazelle-plugin)
  * [3. Create a minimal `Package.swift` file.](#3-create-a-minimal-packageswift-file)
  * [4. Run `swift package update`](#4-run-swift-package-update)
  * [5. Run `bazel mod tidy`.](#5-run-bazel-mod-tidy)
  * [6. Add Gazelle targets to `BUILD.bazel` at the root of your workspace.](#6-add-gazelle-targets-to-buildbazel-at-the-root-of-your-workspace)
  * [7. Create or update Bazel build files for your project.](#7-create-or-update-bazel-build-files-for-your-project)
  * [8. Build and test your project.](#8-build-and-test-your-project)
  * [9. Check in `Package.swift`, `Package.resolved`, and `MODULE.bazel`.](#9-check-in-packageswift-packageresolved-and-modulebazel)
  * [10. Start coding](#10-start-coding)
* [Tips and Tricks](#tips-and-tricks)
<!-- MARKDOWN TOC: END -->

## Documentation

- [Rules and API documentation](/docs/README.md)
- [High-level design](/docs/design/high-level.md)
- [Frequently Asked Questions](/docs/faq.md)

## Prerequisites

### Mac OS

Be sure to install Xcode.

### Linux

You will need to [install Swift](https://swift.org/getting-started/#installing-swift). Make sure
that running `swift --version` works properly.

Don't forget that `rules_swift` [expects the use of
`clang`](https://github.com/bazelbuild/rules_swift#3-additional-configuration-linux-only). Hence,
you will need to specify `CC=clang` before running Bazel.

Finally, help [rules_swift] and [rules_swift_package_manager] find the Swift toolchain by ensuring that a `PATH`
that includes the Swift binary is available in the Bazel actions.

```sh
cat >>local.bazelrc <<EOF
build --action_env=PATH
EOF
```

This approach is necessary to successfully execute the examples on an Ubuntu runner using Github
actions. See the [CI GitHub workflow] for more details.

## Quickstart

The following provides a quick introduction on how to set up and use the features in this
repository. These instructions assume that you are using [Bazel modules] to load your external
dependencies. If you are using Bazel's legacy external dependency management, we recommend using
[Bazel's hybrid mode], then follow the steps in this quickstart guide.

Also, check out the [examples] for more information.

### 1. Enable bzlmod

This repository supports [bzlmod].

```
common --enable_bzlmod
```

### 2. Configure your `MODULE.bazel` to use [rules_swift_package_manager].

Add a dependency on `rules_swift_package_manager`.

<!-- BEGIN MODULE SNIPPET -->
```python
bazel_dep(name = "rules_swift_package_manager", version = "0.37.0")
```
<!-- END MODULE SNIPPET -->

In addition, add the following to load the external dependencies described in your `Package.swift`
and `Package.resolved` files.

```bazel
swift_deps = use_extension(
    "@rules_swift_package_manager//:extensions.bzl",
    "swift_deps",
)
swift_deps.from_package(
    resolved = "//:Package.resolved",
    swift = "//:Package.swift",
)
use_repo(
    swift_deps,
    "swift_deps_info",  # This is generated by the ruleset.
    # The name of the Swift package repositories will be added to this declaration in step 4 after
    # running `bazel mod tidy`.
    # NOTE: The name of the Bazel external repository for a Swift package is `swiftpkg_xxx` where
    # `xxx` is the Swift package identity, lowercase, with punctuation replaced by `hyphen`. For
    # example, the repository name for apple/swift-nio is `swiftpkg_swift_nio`.
)
```

You will also need to add a dependency on [rules_swift].

NOTE: Some Swift package manager features (e.g., resources) use rules from [rules_apple]. It is a
dependency for `rules_swift_package_manager`. However, you do not need to declare it unless you use
any of the rules in your project.

#### (Optional) Enable `swift_deps_info` generation for the Gazelle plugin

If you will be using the Gazelle plugin for Swift, you will need to enable the generation of
the `swift_deps_info` repository by enabling `declare_swift_deps_info`.

```bazel
swift_deps.from_package(
    declare_swift_deps_info = True, # <=== Enable swift_deps_info generation for the Gazelle plugin
    resolved = "//:Package.resolved",
    swift = "//:Package.swift",
)
```

You will also need to add a dependency on [Gazelle](https://registry.bazel.build/modules/gazelle).

### 3. Create a minimal `Package.swift` file.

Create a minimal `Package.swift` file that only contains the external dependencies that are directly
used by your Bazel workspace.

```swift
// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "my-project",
    dependencies: [
        // Replace these entries with your dependencies.
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0"),
        .package(url: "https://github.com/apple/swift-log", from: "1.4.4"),
    ]
)
```

The name of the package can be whatever you like. It is required for the manifest, but it is not
used by [rules_swift_package_manager]. If your project is published and consumed as a Swift package,
feel free to populate the rest of the manifest so that your package works properly by Swift package
manager. Just note that the Swift Gazelle plugin does not use the manifest to generate Bazel build
files, at this time.

### 4. Run `swift package update`

This will invoke Swift Package Manager and resolve all dependencies resulting in creation of
`Package.resolved` file.

### 5. Run `bazel mod tidy`.

This will update your `MODULE.bazel` with the correct `use_repo` declaration.

### 6. Add Gazelle targets to `BUILD.bazel` at the root of your workspace.

Add the following to the `BUILD.bazel` file at the root of your workspace.

```bzl
load("@gazelle//:def.bzl", "gazelle", "gazelle_binary")

# Ignore the `.build` folder that is created by running Swift package manager
# commands. Be sure to configure your source control to ignore it, as well.
# (i.e., add it to your `.gitignore`).
# NOTE: Swift package manager is not used to build any of the external packages.
# gazelle:exclude .build

# This declaration builds a Gazelle binary that incorporates all of the Gazelle
# plugins for the languages that you use in your workspace. In this example, we
# are only listing the Gazelle plugin for Swift from rules_swift_package_manager.
gazelle_binary(
    name = "gazelle_bin",
    languages = [
        "@rules_swift_package_manager//gazelle",
    ],
)

# This target updates the Bazel build files for your project. Run this target
# whenever you add or remove source files from your project. The
# `swift_deps_info` repository is generated by `rules_swift_package_manager`. It
# creates a target, `@swift_deps_info//:swift_deps_index`, that generates a JSON
# file which maps Swift module names to their respective Bazel target.
gazelle(
    name = "update_build_files",
    data = [
        "@swift_deps_info//:swift_deps_index",
    ],
    extra_args = [
        "-swift_dependency_index=$(location @swift_deps_info//:swift_deps_index)",
    ],
    gazelle = ":gazelle_bin",
)
```

### 7. Create or update Bazel build files for your project.

Generate/update the Bazel build files for your project by running the following:

```sh
bazel run //:update_build_files
```

### 8. Build and test your project.

Build and test your project.

```sh
bazel test //...
```

### 9. Check in `Package.swift`, `Package.resolved`, and `MODULE.bazel`.

- The `Package.swift` file is used by `rules_swift_package_manager` to generate information about
  your project's dependencies.
- The `Package.resolved` file specifies that exact versions of the downloaded dependencies that were
  identified.
- The `MODULE.bazel` contains the declarations for your external dependencies.

### 10. Start coding

You are ready to start coding.

## Tips and Tricks

The following are a few tips to consider as you work with your repository:

- When you add or remove source files, run `bazel run //:update_build_files`. This will
  create/update the Bazel build files in your project. It is designed to be fast and unobtrusive.
- If things do not appear to be working properly, run the following:
  - `bazel run //:update_build_files`
- Do yourself a favor and create a Bazel target (e.g., `//:tidy`) that runs your repository
  maintenance targets (e.g., `//:update_build_files`, formatting utilities)
  in the proper order. If you are looking for an easy way to set this up, check out the
  [`//:tidy` declaration in this repository](BUILD.bazel) and the documentation for the [tidy] macro.
- Are you trying to use a Swift package and it just won't build under Bazel? If you can figure out
  how to fix it, you can patch the Swift package. Check out [our document on patching Swift packages].

<!-- Links -->

[Bazel modules]: https://bazel.build/external/module
[Bazel's hybrid mode]: https://bazel.build/external/migration#hybrid-mode
[bzlmod]: https://bazel.build/external/overview#bzlmod
[our document on patching Swift packages]: docs/patch_swift_package.md
[CI GitHub workflow]: .github/workflows/ci.yml
[Gazelle plugin]: https://github.com/bazelbuild/bazel-gazelle/blob/master/extend.md
[Gazelle]: https://github.com/bazelbuild/bazel-gazelle
[examples]: examples/
[rules_apple]: https://github.com/bazelbuild/rules_apple
[rules_spm]: https://github.com/cgrindel/rules_spm
[rules_swift]: https://github.com/bazelbuild/rules_swift
[rules_swift_package_manager]: https://github.com/cgrindel/rules_swift_package_manager
[tidy]: https://github.com/cgrindel/bazel-starlib/blob/main/doc/bzltidy/rules_and_macros_overview.md#tidy
