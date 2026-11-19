function bazel
    if test -f .bazelversion; and grep -qE '\*' .bazelversion
        USE_BAZEL_VERSION=7.6.0 command bazel $argv
    else
        command bazel $argv
    end
end
