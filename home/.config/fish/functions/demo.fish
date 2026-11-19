function demo --description "Find and run a demo function via bazel (staging)"
    if test (count $argv) -lt 1
        echo "Usage: demo <FunctionName> [extra args...]"
        return 1
    end

    set func_name $argv[1]
    set extra_args $argv[2..]
    set repo_root (git rev-parse --show-toplevel)

    set match (grep -rl "func (c \*Caller) $func_name(" $repo_root --include="*.go" | head -1)
    if test -z "$match"
        echo "Function $func_name not found in any demo package"
        return 1
    end

    set demo_dir (dirname $match)
    set rel_path (string replace "$repo_root/" "" $demo_dir)
    set target "//$rel_path:demo"

    echo "Found $func_name in $rel_path"
    echo "Running: bazel run $target -- $func_name $extra_args"
    bazel run $target -- $func_name $extra_args
end
