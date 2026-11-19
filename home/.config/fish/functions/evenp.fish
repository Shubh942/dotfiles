function evenp --description "Find and run a bazel target by name (prod)"
    if test (count $argv) -lt 1
        echo "Usage: evenp <target_name> [extra args...]"
        return 1
    end

    set target_name $argv[1]
    set extra_args $argv[2..]
    set repo_root (git rev-parse --show-toplevel)

    # Try exact match first, then strip _deploy suffix
    set match (grep -rl "name = \"$target_name\"" $repo_root --include="BUILD" | head -1)
    if test -z "$match"
        set base_name (string replace -r '_deploy$' '' $target_name)
        set match (grep -rl "name = \"$base_name\"" $repo_root --include="BUILD" | head -1)
    end

    if test -z "$match"
        echo "Target $target_name not found in any BUILD file"
        return 1
    end

    set pkg_dir (dirname $match)
    set rel_path (string replace "$repo_root/" "" $pkg_dir)
    set target "//$rel_path:$target_name"

    nvm use 18
    echo "Running: ENVIRONMENT=prod bazel run $target $extra_args"
    ENVIRONMENT=prod bazel run $target $extra_args
end
