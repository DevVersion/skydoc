# Copyright 2016 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Skylark rules"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("//third_party/bazel_skylib:skylark_library.bzl", "SkylarkLibraryInfo")

_SKYLARK_FILETYPE = FileType([".bzl"])

ZIP_PATH = "/usr/bin/zip"

def _skydoc(ctx):
    for f in ctx.files.skydoc:
        if not f.path.endswith(".py"):
            return f

def _skylark_doc_impl(ctx):
    """Implementation of the skylark_doc rule."""
    skylark_doc_zip = ctx.outputs.skylark_doc_zip
    direct = []
    transitive = []
    for dep in ctx.attr.srcs:
        if SkylarkLibraryInfo in dep:
            direct.extend(dep[SkylarkLibraryInfo].srcs)
            transitive.append(dep[SkylarkLibraryInfo].transitive_srcs)
        else:
            direct.extend(dep.files.to_list())
    inputs = depset(order = "postorder", direct = direct, transitive = transitive + [
        dep[SkylarkLibraryInfo].transitive_srcs
        for dep in ctx.attr.deps
    ])
    sources = [source.path for source in direct]
    flags = [
        "--format=%s" % ctx.attr.format,
        "--output_file=%s" % ctx.outputs.skylark_doc_zip.path,
    ]
    if ctx.attr.strip_prefix:
        flags += ["--strip_prefix=%s" % ctx.attr.strip_prefix]
    if ctx.attr.overview:
        flags += ["--overview"]
    if ctx.attr.overview_filename:
        flags += ["--overview_filename=%s" % ctx.attr.overview_filename]
    if ctx.attr.link_ext:
        flags += ["--link_ext=%s" % ctx.attr.link_ext]
    if ctx.attr.site_root:
        flags += ["--site_root=%s" % ctx.attr.site_root]
    skydoc = _skydoc(ctx)
    ctx.action(
        inputs = list(inputs) + [skydoc],
        executable = skydoc,
        arguments = flags + sources,
        outputs = [skylark_doc_zip],
        mnemonic = "Skydoc",
        use_default_shell_env = True,
        progress_message = ("Generating Skylark doc for %s (%d files)" %
                            (ctx.label.name, len(sources))),
    )

skylark_doc = rule(
    _skylark_doc_impl,
    attrs = {
        "srcs": attr.label_list(
            providers = [SkylarkLibraryInfo],
            allow_files = _SKYLARK_FILETYPE,
        ),
        "deps": attr.label_list(
            providers = [SkylarkLibraryInfo],
            allow_files = False,
        ),
        "format": attr.string(default = "markdown"),
        "strip_prefix": attr.string(),
        "overview": attr.bool(default = True),
        "overview_filename": attr.string(),
        "link_ext": attr.string(),
        "site_root": attr.string(),
        "skydoc": attr.label(
            default = Label("//third_party/py/skydoc/skydoc"),
            cfg = "host",
            executable = True,
        ),
    },
    outputs = {
        "skylark_doc_zip": "%{name}-skydoc.zip",
    },
)
"""Generates Skylark rule documentation.

Documentation is generated in directories that follows the package structure
of the input `.bzl` files. For example, suppose the set of input files are
as follows:

* `foo/foo.bzl`
* `foo/bar/bar.bzl`

The archive generated by `skylark_doc` will contain the following generated
docs:

* `foo/foo.html`
* `foo/bar/bar.html`

Args:
  srcs: List of `.bzl` files that are processed to create this target.
  deps: List of other `skylark_library` targets that are required by the Skylark
    files listed in `srcs`.
  format: The type of output to generate. Possible values are `"markdown"` and
    `"html"`.
  strip_prefix: The directory prefix to strip from the generated output files.

    The directory prefix to strip must be common to all input files. Otherwise,
    skydoc will raise an error.
  overview: If set to `True`, then generate an overview page.
  overview_filename: The file name to use for the overview page. By default,
    the page is named `index.md` or `index.html` for Markdown and HTML output
    respectively.
  link_ext: The file extension used for links in the generated documentation.
    By default, skydoc uses `.html`.
  site_root: The site root to be prepended to all URLs in the generated
    documentation, such as links, style sheets, and images.

    This is useful if the generated documentation is served from a subdirectory
    on the web server. For example, if the skydoc site is to served from
    `https://host.com/rules`, then by setting
    `site_root = "https://host.com/rules"`, all links will be prefixed with
    the site root, for example, `https://host.com/rules/index.html`.

Outputs:
  skylark_doc_zip: A zip file containing the generated documentation.

Example:
  Suppose you have a project containing Skylark rules you want to document:

  ```
  [workspace]/
      WORKSPACE
      checkstyle/
          BUILD
          checkstyle.bzl
  ```

  To generate documentation for the rules and macros in `checkstyle.bzl`, add the
  following target to `rules/BUILD`:

  ```python
  load("@io_bazel_skydoc//third_party/py/skydoc/skylark:skylark.bzl", "skylark_doc")

  skylark_doc(
      name = "checkstyle-docs",
      srcs = ["checkstyle.bzl"],
  )
  ```

  Running `bazel build //checkstyle:checkstyle-docs` will generate a zip file
  containing documentation for the public rules and macros in `checkstyle.bzl`.

  By default, Skydoc will generate documentation in Markdown. To generate
  a set of HTML pages that is ready to be served, set `format = "html"`.
"""

JINJA2_BUILD_FILE = """
py_library(
    name = "jinja2",
    srcs = glob(["jinja2/*.py"]),
    srcs_version = "PY2AND3",
    deps = [
        "@markupsafe_archive//:markupsafe",
    ],
    visibility = ["//visibility:public"],
)
"""

MARKUPSAFE_BUILD_FILE = """
py_library(
    name = "markupsafe",
    srcs = glob(["markupsafe/*.py"]),
    srcs_version = "PY2AND3",
    visibility = ["//visibility:public"],
)
"""

MISTUNE_BUILD_FILE = """
py_library(
    name = "mistune",
    srcs = ["mistune.py"],
    srcs_version = "PY2AND3",
    visibility = ["//visibility:public"],
)
"""

SIX_BUILD_FILE = """
py_library(
    name = "six",
    srcs = ["six.py"],
    srcs_version = "PY2AND3",
    visibility = ["//visibility:public"],
)
"""

GFLAGS_BUILD_FILE = """
py_library(
    name = "gflags",
    srcs = [
        "gflags.py",
        "gflags_validators.py",
    ],
    visibility = ["//visibility:public"],
)
"""

def skydoc_repositories():
    """Adds the external repositories used by the skylark rules."""
    http_archive(
        name = "protobuf",
        urls = ["https://github.com/google/protobuf/archive/v3.4.1.tar.gz"],
        sha256 = "8e0236242106e680b4f9f576cc44b8cd711e948b20a9fc07769b0a20ceab9cc4",
        strip_prefix = "protobuf-3.4.1",
    )

    # Protobuf expects an //external:python_headers label which would contain the
    # Python headers if fast Python protos is enabled. Since we are not using fast
    # Python protos, bind python_headers to a dummy target.
    native.bind(
        name = "python_headers",
        actual = "//:dummy",
    )

    native.new_http_archive(
        name = "markupsafe_archive",
        urls = ["https://pypi.python.org/packages/source/M/MarkupSafe/MarkupSafe-0.23.tar.gz#md5=f5ab3deee4c37cd6a922fb81e730da6e"],
        sha256 = "a4ec1aff59b95a14b45eb2e23761a0179e98319da5a7eb76b56ea8cdc7b871c3",
        build_file_content = MARKUPSAFE_BUILD_FILE,
        strip_prefix = "MarkupSafe-0.23",
    )

    native.bind(
        name = "markupsafe",
        actual = "@markupsafe_archive//:markupsafe",
    )

    http_archive(
        name = "jinja2_archive",
        urls = ["https://pypi.python.org/packages/source/J/Jinja2/Jinja2-2.8.tar.gz#md5=edb51693fe22c53cee5403775c71a99e"],
        sha256 = "bc1ff2ff88dbfacefde4ddde471d1417d3b304e8df103a7a9437d47269201bf4",
        build_file_content = JINJA2_BUILD_FILE,
        strip_prefix = "Jinja2-2.8",
    )

    native.bind(
        name = "jinja2",
        actual = "@jinja2_archive//:jinja2",
    )

    http_archive(
        name = "mistune_archive",
        urls = ["https://pypi.python.org/packages/source/m/mistune/mistune-0.7.1.tar.gz#md5=057bc28bf629d6a1283d680a34ed9d0f"],
        sha256 = "6076dedf768348927d991f4371e5a799c6a0158b16091df08ee85ee231d929a7",
        build_file_content = MISTUNE_BUILD_FILE,
        strip_prefix = "mistune-0.7.1",
    )

    native.bind(
        name = "mistune",
        actual = "@mistune_archive//:mistune",
    )

    http_archive(
        name = "six_archive",
        urls = ["https://pypi.python.org/packages/source/s/six/six-1.10.0.tar.gz#md5=34eed507548117b2ab523ab14b2f8b55"],
        sha256 = "105f8d68616f8248e24bf0e9372ef04d3cc10104f1980f54d57b2ce73a5ad56a",
        build_file_content = SIX_BUILD_FILE,
        strip_prefix = "six-1.10.0",
    )

    native.bind(
        name = "six",
        actual = "@six_archive//:six",
    )

    http_archive(
        name = "gflags_repo",
        urls = ["https://github.com/google/python-gflags/archive/python-gflags-2.0.zip"],
        sha256 = "344990e63d49b9b7a829aec37d5981d558fea12879f673ee7d25d2a109eb30ce",
        build_file_content = GFLAGS_BUILD_FILE,
        strip_prefix = "python-gflags-python-gflags-2.0",
    )

    native.bind(
        name = "gflags",
        actual = "@gflags_repo//:gflags",
    )
