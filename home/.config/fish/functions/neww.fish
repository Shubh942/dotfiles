function neww --description "Spin up a fresh scratch worktree from the bare monorepo"
    set bare_repo /home/shubh/Documents/repos/monorepo
    set worktrees_dir /home/shubh/Documents/repos
    set rand (cat /dev/urandom | tr -dc 'a-z0-9' | head -c 6 2>/dev/null)
    set ts (date +%Y%m%d-%H%M%S)
    set label (if test (count $argv) -gt 0; echo $argv[1]; else; echo scratch; end)
    set branch scratch/$ts-$rand
    set dir $worktrees_dir/$label-$ts-$rand
    echo "Fetching origin..."
    git -C $bare_repo fetch origin
    echo "Rebasing master onto origin/master..."
    git -C $bare_repo rebase origin/master master
    echo "Creating worktree: $dir  (branch: $branch)"
    git -C $bare_repo worktree add -b $branch $dir master
    cd $dir
    echo "Done. You are now in $dir"
end
