function worky -d "Manages git worktrees"
    set -l subcommand $argv[1]
    set -l args $argv[2..-1]

    if not command -sq git
        echo "Error: git is not installed. Please install git to use this command."
        return 1
    end

    if not command -sq fzf
        echo "Error: fzf is not installed. Please install fzf to use this command."
        return 1
    end

    switch $subcommand
        case i or init
            _worky_init $args
        case a or add
            _worky_add $args
        case d or delete
            _worky_delete $args
        case -h
            echo "Worky is an opinionated tool for working with Git Worktrees"
            echo ""
            echo "Usage: worky <command> [options]"
            echo "Commands:"
            echo "  init,i     - Init a bare repo for worky usage"
            echo "  list,ls    - List worktrees and navigate to one"
            echo "  add,a      - Add a new worktree"
            echo "  delete,d   - Delete a worktree"
        case ls or list or "*"
            _worky_list $args

    end
end

function _worky_init -d "Clones a Git repository as a bare repo."
    argparse 'u/url=' -- $argv

    if not set -q _flag_url
        echo "Usage: worktree init -u <repository_url>"
        return 1
    end

    set -l url $_flag_url

    echo "Cloning bare repository from '$url' to 'project.git'..."
    git clone --bare "$url" "project.git"

    if test $status -eq 0
        echo "Bare repository cloned successfully to '$repo_name.git'."
    else
        echo "Error cloning repository. Please check the URL and your network connection."
    end

    _worky_add -n main
end

function _worky_add -d "Creates a new Git worktree."
    argparse 'n/name=' 'b/branch=' f/force -- $argv

    if not set -q _flag_name
        echo "Usage: worktree add -n <worktree_name> [-b <branch_name>][-f]"
        return 1
    end

    _worky_cd
    if test $status -ne 0
        echo "Error: Not in a git repository."
        return 1
    end

    set -l branch $_flag_branch
    set -l force_flag ""

    if set -q _flag_force
        set force_flag --force
    end

    if test (basename (pwd)) = "project.git"
        set path (realpath "../")/$_flag_name
    else
        set path (dirname (git rev-parse --show-toplevel))/$_flag_name
    end

    if string length --quiet $branch
        if git rev-parse --verify --quiet $branch >/dev/null
            echo "A ref named '$branch' (local branch, tag, or commit) exists. Exiting."
            return 1
        end
        echo "Creating worktree at '$path' for branch '$branch'..."
        git worktree add $force_flag "$path" -B "$branch"
    else
        echo "Creating worktree at '$path'..."
        git worktree add "$path"
    end

    if test $status -eq 0
        echo "Worktree created successfully at '$path'."
    else
        echo "Error creating worktree. Please check the path and branch name."
    end
end

function _worky_list -d "Lists Git worktrees and navigates to the selected one using fzf."
    # check if in git repo
    _worky_cd
    if test $status -ne 0
        echo "Error: Not in a git repository."
        return 1
    end

    set -l selected (git worktree list | sed -r 's/^(.*\/([^[:space:]]* ))/\1 \2/g' | fzf --with-nth=2,4 --height 10 --border --prompt "tree: ")

    if test -z "$selected"
        echo "No worktree selected."
        return 0
    end

    set -l selected_branch (echo $selected | cut -d" " -f3)
    set -l selected_dir (echo $selected | cut -d" " -f1)

    echo "Selected branch: [$selected_branch]. Selected directory: [$selected_dir]"

    cd $selected_dir
    ####################################################### works above here

    #
    # set -l paths
    # for line in $worktrees
    #     echo "Evaluating line: $line"
    #     if string match -q "^worktree " $line
    #         set paths $paths (string trim (string replace "worktree " "" $line))
    #     end
    # end
    # echo "Worktrees found: $paths"

    ########################################################## sorta works above here
    #
    # if not $paths
    #     echo "No worktrees found."
    #     return 0
    # end

    # set -l selected (echo "$paths" | fzf --height $(( (count $paths) + 2 )) --prompt 'Select worktree: ')
    #
    # if test -n "$selected"
    #     if test -d "$selected"
    #         echo "Navigating to '$selected'..."
    #         cd "$selected"
    #     else
    #         echo "Error: Selected path '$selected' is not a valid directory."
    #     end
    # else
    #     echo "No worktree selected."
    # end
end

function _worky_delete -d "Deletes a Git worktree."
    argparse f/force -- $argv

    _worky_cd
    if test $status -ne 0
        echo "Error: Not in a git repository."
        return 1
    end

    set -l force_flag
    if set -q _flag_force
        set force_flag --force
    end

    set -l selected (git worktree list | sed -r 's/^(.*\/([^[:space:]]* ))/\1 \2/g' | fzf --with-nth=2,4 --height 10 --border --prompt "tree: ")

    if test -z "$selected"
        echo "No worktree selected."
        return 0
    end

    echo "selected: $selected"
    set -l selected_dir (string trim (echo $selected | cut -d" " -f3))

    echo "Deleting worktree '$selected_dir'..."
    git worktree remove $selected_dir $force_flag

    if test $status -eq 0
        echo "Worktree '$selected_dir' deleted successfully."
    else
        echo "Error deleting worktree. Please check the path or try with --force."
    end
end

function _worky_cd
    set -l worktrees (git worktree list --porcelain 2>&1)
    if test $status -ne 0
        echo "No worktrees found in current directory."
        # check if project.git folder exists 
        if test -d "project.git"
            echo "Found project.git. Changing to project.git..."
            cd "project.git"
        else
            echo "This is not a git repository."
            return 1
        end
    end
end
