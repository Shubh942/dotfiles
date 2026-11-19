function git-submit
    git review -t (basename (pwd))/(git branch --show-current) $argv
end
