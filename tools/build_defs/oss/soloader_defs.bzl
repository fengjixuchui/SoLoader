def _deps_decorator(**kwargs):
    """
    Dependencies starting with '//deps:' should be provided (included in
    'provided_deps' rather than 'deps'). This decorator takes care
    of moving all such dependencies from 'deps' to 'provided_deps'.
    """
    all_deps = kwargs.get("deps", [])
    oss_deps = [dep for dep in all_deps if dep.startswith("//deps:")]
    kwargs["deps"] = [dep for dep in all_deps if dep not in oss_deps]
    kwargs.setdefault("provided_deps", []).extend(oss_deps)
    return kwargs

def android_library(**kwargs):
    native.android_library(**_deps_decorator(**kwargs))

def android_aar(**kwargs):
    native.android_aar(**_deps_decorator(**kwargs))

def fb_java_library(**kwargs):
    native.java_library(**_deps_decorator(**kwargs))

def fb_core_android_library(**kwargs):
    android_library(**kwargs)

def export_file(**kwargs):
    native.export_file(**kwargs)

def _add_dependency_to_index(name, DEPENDENCIES_INDEX, **dep):
    DEPENDENCIES_INDEX[name] = dep

def maven_library(
        name,
        DEPENDENCIES_INDEX,
        group,
        artifact,
        version,
        sha1,
        visibility,
        packaging = "jar",
        scope = "compiled"):
    """
    Creates remote_file and prebuilt_jar rules for a maven artifact.
    """
    _add_dependency_to_index(
        name = name,
        DEPENDENCIES_INDEX = DEPENDENCIES_INDEX,
        artifact = artifact,
        group = group,
        packaging = packaging,
        scope = scope,
        sha1 = sha1,
        version = version,
    )

    remote_file_name = "{}-remote".format(name)
    native.remote_file(
        name = remote_file_name,
        out = "{}-{}.{}".format(name, version, packaging),
        url = ":".join(["mvn", group, artifact, packaging, version]),
        sha1 = sha1,
    )

    if packaging == "jar":
        native.prebuilt_jar(
            name = name,
            binary_jar = ":{}".format(remote_file_name),
            visibility = visibility,
        )
    else:
        native.android_prebuilt_aar(
            name = name,
            aar = ":{}".format(remote_file_name),
            visibility = visibility,
        )

def _to_json(x):
    if hasattr(native, "json"):
        return native.json.encode(x)
    else:
        return x.to_json()

def define_list_deps_target(DEPENDENCIES_INDEX):
    """
    Generates rule that dumps all maven_libraries defined in given
    BUCK file in json format.
    """
    json_deps = _to_json(struct(**DEPENDENCIES_INDEX))
    native.genrule(
        name = "list-deps",
        out = "dependencies.json",
        cmd = """echo '{}' > $OUT""".format(json_deps),
    )
