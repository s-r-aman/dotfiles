# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Brew path addtion for bin
export PATH=/opt/homebrew/bin:~/nvim-osx64/bin/nvim:/usr/local/bin/webstorm:/Users/vidyoai/Library/Python/3.9/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to automatically update without prompting.
# DISABLE_UPDATE_PROMPT="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git zsh-autosuggestions zsh-syntax-highlighting macos thefuck lol iterm2 fzf cp copypath brew alias-finder vscode)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8
#
# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
alias reload="source ~/.zshrc"
alias editsh="nvim ~/.zshrc"
alias lsa="eza -a --icons"
alias lla="eza -la --icons"
alias ll="eza -l --icons"
alias brew="/opt/homebrew/bin/brew"
alias gc="git clone"
alias bu="brew uninstall"
alias bi="brew install"
alias npi="npm install"
alias npb="npm run build"
alias yolo="rm -rf node_modules; npm install"
alias gs="git switch"
alias gsc="git switch -c"
alias master="git switch master && git pull origin master"
alias staging="git switch staging && git pull origin staging"
alias stg="git switch staging && git pull origin staging"
alias renx="brew services restart nginx"
alias ghprlink="gh pr view --json url -q .url | tee >(pbcopy) && echo 'PR link copied to clipboard'"
alias ghprcreate="gh pr create --body '' --title"
alias myprs="gh pr list --author @me"
alias myprco="gh pr list --author @me | fzf | awk '{print \$1}' | xargs gh pr checkout"
alias ghrr="gh pr list --search 'review-requested:@me' | fzf --preview 'gh pr view {1}' --preview-window=right:50%:wrap | awk '{print \$1}' | xargs gh pr checkout"
alias ghrrv="pr_num=\$(gh pr list --search 'review-requested:@me' | fzf --preview 'gh pr view {1}' --preview-window=right:50%:wrap | awk '{print \$1}') && gh pr checkout \$pr_num && claude \"open the project and review this pr: \$pr_num\""

export NVM_DIR="$HOME/.nvm"
  [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && . "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm
  [ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && . "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion
eval "$(starship init zsh)"

export EDITOR='nvim'

# Set the global python version
eval "$(pyenv init --path)"

# Init zoxide
eval "$(zoxide init zsh)"
export PATH="$HOME/.local/bin:$PATH"
