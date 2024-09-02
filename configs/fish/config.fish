# Fish shell config
# Last modified: 31-07-2024

set fish_greeting

# Kanagawa Fish shell theme
# A template was taken and modified from Tokyonight:
# https://github.com/folke/tokyonight.nvim/blob/main/extras/fish_tokyonight_night.fish
set -l foreground DCD7BA normal
set -l selection 2D4F67 brcyan
set -l comment 727169 brblack
set -l red C34043 red
set -l orange FF9E64 brred
set -l yellow C0A36E yellow
set -l green 76946A green
set -l purple 957FB8 magenta
set -l cyan 7AA89F cyan
set -l pink D27E99 brmagenta

# Syntax Highlighting Colors
set -g fish_color_normal $foreground
set -g fish_color_command $cyan
set -g fish_color_keyword $pink
set -g fish_color_quote $yellow
set -g fish_color_redirection $foreground
set -g fish_color_end $orange
set -g fish_color_error $red
set -g fish_color_param $purple
set -g fish_color_comment $comment
set -g fish_color_selection --background=$selection
set -g fish_color_search_match --background=$selection
set -g fish_color_operator $green
set -g fish_color_escape $pink
set -g fish_color_autosuggestion $comment

# Completion Pager Colors
set -g fish_pager_color_progress $comment
set -g fish_pager_color_prefix $cyan
set -g fish_pager_color_completion $foreground
set -g fish_pager_color_description $comment

set -g GOPATH $HOME/.local/go

eval $(starship init fish)
eval $(opam env)
zoxide init fish | source

alias "cd"="z"
alias "cg"="cd \$(git rev-parse --show-toplevel)"
alias "pwdr"="pwd > /tmp/.$USER\pwdremember"
alias "cdr"="cd \$(cat /tmp/.$USER\pwdremember)"
alias "vim"="nvim"
alias "ls"="eza --icons --group-directories-first"
alias "la"="ls -a"
alias "ll"="la -l -X -@ -Z"
alias "lg"="git status >/dev/null && echo \"Git repo: \$(git remote get-url origin)\" && git show origin && echo -e \"Files:\" && ll --git --git-repos --git-ignore"
