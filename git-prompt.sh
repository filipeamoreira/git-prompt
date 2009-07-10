
        # don't set prompt if this is not interactive shell
        [[ $- != *i* ]]  &&  return

###################################################################   CONFIG

        #####  read config file if any.

        unset   dir_color rc_color root_id_color init_vcs_color clean_vcs_color
        unset modified_vcs_color added_vcs_color mixed_vcs_color untracked_vcs_color op_vcs_color detached_vcs_color

        conf=git-prompt.conf;                   [[ -r $conf ]]  && . $conf
        conf=/etc/git-prompt.conf;              [[ -r $conf ]]  && . $conf
        conf=~/.git-prompt.conf;                [[ -r $conf ]]  && . $conf
        unset conf

        #####  set defaults if not set

        git_module=${git_module:-on}
        svn_module=${svn_module:-off}
        hg_module=${hg_module:-on}
        vim_module=${vim_module:-on}
        error_bell=${error_bell:-off}
        cwd_cmd=${cwd_cmd:-\\w}


        #### dir, rc, root color 
        if [ 0`tput colors` -ge 8 ];  then                              #  if terminal supports colors
                dir_color=${dir_color:-CYAN}
                rc_color=${rc_color:-red}
                root_id_color=${root_id_color:-magenta}
        else                                                                                    #  only B/W
                dir_color=${dir_color:-bw_bold}
                rc_color=${rc_color:-bw_bold}
        fi

        #### vcs state colors
                 init_vcs_color=${init_vcs_color:-WHITE}                # initial
                clean_vcs_color=${clean_vcs_color:-blue}                # nothing to commit (working directory clean)
             modified_vcs_color=${modified_vcs_color:-red}      # Changed but not updated:
                added_vcs_color=${added_vcs_color:-green}       # Changes to be committed:
                mixed_vcs_color=${mixed_vcs_color:-yellow}
            untracked_vcs_color=${untracked_vcs_color:-BLUE}    # Untracked files:
                   op_vcs_color=${op_vcs_color:-MAGENTA}
             detached_vcs_color=${detached_vcs_color:-RED}

        max_file_list_length=${max_file_list_length:-100}
        upcase_hostname=${upcase_hostname:-on}


#####################################################################  post config

        ################# make PARSE_VCS_STATUS
                                                                    PARSE_VCS_STATUS=""
        [[ $git_module = "on" ]]   &&   type git >&/dev/null   &&   PARSE_VCS_STATUS="parse_git_status"
        [[ $svn_module = "on" ]]   &&   type svn >&/dev/null   &&   PARSE_VCS_STATUS+="||parse_svn_status"
        [[ $hg_module  = "on" ]]   &&   type hg  >&/dev/null   &&   PARSE_VCS_STATUS+="||parse_hg_status"
                                                                    PARSE_VCS_STATUS+="||return"
        ################# terminfo colors-16
        #
        #       black?    0 8                     
        #       red       1 9
        #       green     2 10
        #       yellow    3 11
        #       blue      4 12
        #       magenta   5 13
        #       cyan      6 14
        #       white     7 15
        #
        #       terminfo setaf/setab - sets ansi foreground/background
        #       terminfo sgr0 - resets all attributes
        #       terminfo colors - number of colors
        #
        #################  Colors-256
        #  To use foreground and background colors from the extension, you only
        #  have to remember two escape codes:
        #       Set the foreground color to index N:    \033[38;5;${N}m
        #       Set the background color to index M:    \033[48;5;${M}m
        # To make vim aware of a present 256 color extension, you can either set
        # the $TERM environment variable to xterm-256color or use vim's -T option
        # to set the terminal. I'm using an alias in my bashrc to do this. At the
        # moment I only know of two color schemes which is made for multi-color
        # terminals like urxvt (88 colors) or xterm: inkpot and desert256, 

        ### if term support colors,  then use color prompt, else bold

              black='\['`tput sgr0; tput setaf 0`'\]'
                red='\['`tput sgr0; tput setaf 1`'\]'
              green='\['`tput sgr0; tput setaf 2`'\]'
             yellow='\['`tput sgr0; tput setaf 3`'\]'
               blue='\['`tput sgr0; tput setaf 4`'\]'
            magenta='\['`tput sgr0; tput setaf 5`'\]'
               cyan='\['`tput sgr0; tput setaf 6`'\]'
              white='\['`tput sgr0; tput setaf 7`'\]'

              BLACK='\['`tput setaf 0; tput bold`'\]'
                RED='\['`tput setaf 1; tput bold`'\]'
              GREEN='\['`tput setaf 2; tput bold`'\]'
             YELLOW='\['`tput setaf 3; tput bold`'\]'
               BLUE='\['`tput setaf 4; tput bold`'\]'
            MAGENTA='\['`tput setaf 5; tput bold`'\]'
               CYAN='\['`tput setaf 6; tput bold`'\]'  # why 14 doesn't work?
              WHITE='\['`tput setaf 7; tput bold`'\]'

            bw_bold='\['`tput bold`'\]'

        on=''
        off=': '
        
        bell="\[`eval ${!error_bell} tput bel`\]"

        colors_reset='\['`tput sgr0`'\]'

        # Workaround for UTF readline(?) bug. Disable bell when UTF
        #locale |grep -qi UTF && bell=''        


        # replace symbolic colors names to raw treminfo strings
                 init_vcs_color=${!init_vcs_color}
             modified_vcs_color=${!modified_vcs_color}
            untracked_vcs_color=${!untracked_vcs_color}
                clean_vcs_color=${!clean_vcs_color}
                added_vcs_color=${!added_vcs_color}
                   op_vcs_color=${!op_vcs_color}
                mixed_vcs_color=${!mixed_vcs_color}
             detached_vcs_color=${!detached_vcs_color}


        unset PROMPT_COMMAND

        #######  work around for MC bug
        if [ -z "$TERM" -o "$TERM" = "dumb" -o -n "$MC_SID" ]; then
                unset PROMPT_COMMAND
                PS1='\w> '
                return 0
        fi

        ####################################################################  MARKERS
        screen_marker="sCRn"
        if [[ $LANG =~ "UTF" ]];  then 
                truncated_marker="…"
        else
                truncated_marker="..."
        fi

        export who_where


cwd_truncate() {
        # based on:   https://www.blog.montgomerie.net/pwd-in-the-title-bar-or-a-regex-adventure-in-bash
        # TODO: never abbrivate last  dir

        # arg1: max path lenght
        # returns abbrivated $PWD  in public "cwd" var

        cwd=${PWD/$HOME/\~}             # substitute  "~"

        case $1 in
                full)
                        return 
                        ;;
                last)
                        cwd=${PWD##/*/}
                        [[ $PWD == $HOME ]] && cwd="~"
                        return 
                        ;;
                *)
                        local cwd_max_length=$1
                        ;;
        esac

                # split path into:  head='~/',  truncapable middle,  last_dir
        if [[ "$cwd" =~ (~?/)(.*)/([^/]*) ]] ;  then  # only valid if path have more then 1 dir
                path_head=${BASH_REMATCH[1]}
                path_middle=${BASH_REMATCH[2]}
                path_last_dir=${BASH_REMATCH[3]}

                # if middle is too long, truncate

                cwd_middle_max=$(($cwd_max_length +${#truncated_marker}+1 - ${#path_last_dir}))
                [[ $cwd_middle_max < 0  ]] && cwd_middle_max=0

                if [[ $path_middle =~ (.{$(($cwd_middle_max))})$ ]];  then
                        cwd=$path_head$truncated_marker${BASH_REMATCH[1]}/$path_last_dir
                fi
        fi
        return
 }


set_shell_label() { 

        xterm_label() { echo  -n "]2;${@}" ; }   # FIXME: replace hardcodes with terminfo codes

        screen_label() { 
                # FIXME: run this only if screen is in xterm (how to test for this?)
                xterm_label  "$screen_marker  $plain_who_where $@" 

                # FIXME $STY not inherited though "su -"
                [ "$STY" ] && screen -S $STY -X title "$*"
        }

        case $TERM in

                screen*)                                                    
                        screen_label "$*"
                        ;;

                xterm* | rxvt* | gnome-terminal | konsole | eterm | wterm )       
                        # is there a capability which we can to test 
                        # for "set term title-bar" and its escapes?
                        xterm_label  "$plain_who_where $@"
                        ;;

                *)                                                     
                        ;;
        esac
 }

    export -f set_shell_label

###################################################### ID (user name)
        id=`id -un`
        id=${id#$default_user}

########################################################### TTY
        tty=`tty`
        tty=`echo $tty | sed "s:/dev/pts/:p:; s:/dev/tty::" `           # RH tty devs   
        tty=`echo $tty | sed "s:/dev/vc/:vc:" `                         # gentoo tty devs

        if [[ "$TERM" = "screen" ]] ;  then

                #       [ "$WINDOW" = "" ] && WINDOW="?"
                #       
                #               # if under screen then make tty name look like s1-p2
                #               # tty="${WINDOW:+s}$WINDOW${WINDOW:+-}$tty"
                #       tty="${WINDOW:+s}$WINDOW"  # replace tty name with screen number
                tty="$WINDOW"  # replace tty name with screen number
        fi

        # we don't need tty name under X11
        case $TERM in
                xterm* | rxvt* | gnome-terminal | konsole | eterm | wterm )  unset tty ;;
                *);;
        esac

        dir_color=${!dir_color}
        rc_color=${!rc_color}
        root_id_color=${!root_id_color}

        ########################################################### HOST
        ### we don't display home host/domain  $SSH_* set by SSHD or keychain

        # How to find out if session is local or remote? Working with "su -", ssh-agent, and so on ? 
        ## is sshd our parent?
        # if    { for ((pid=$$; $pid != 1 ; pid=`ps h -o pid --ppid $pid`)); do ps h -o command -p $pid; done | grep -q sshd && echo == REMOTE ==; }
        #then 
        host=${HOSTNAME}
        #host=`hostname --short`
        if [[ $upcase_hostname = "on" ]]; then 
                host=`echo ${host%$default_host} | tr a-z A-Z`
        else
                host=${host%$default_host}
        fi
        
        host_color=${host}_host_color
        host_color=${!host_color}
        if [[ -z $host_color && -x /usr/bin/cksum ]] ;  then 
                cksum_color_no=`echo $host | cksum  | awk '{print $1%7}'`
                color_index=(green yellow blue magenta cyan white)              # FIXME:  bw,  color-256
                host_color=${color_index[cksum_color_no]}
        fi

        host_color=${!host_color}

        # we already should have short host name, but just in case
        host=${host%.$localdomain}
        host=${host%.$default_domain}


#################################################################### WHO_WHERE 
        #  [[user@]host[-tty]]
        
        if [[ -n $id  || -n $host ]] ;   then 
                [[ -n $id  &&  -n $host ]]  &&  at='@'  || at=''
                color_who_where="${id}$at${host:+$host_color$host}${tty:+ $tty}"
                plain_who_where="${id}$at$host"

                # add trailing " "
                color_who_where="$color_who_where "
                plain_who_where="$plain_who_where "
                
                # if root then make it root_color
                if      [ "$id" == "root" ]  ; then 
                    color_who_where="$root_id_color$color_who_where$colors_reset"
                fi
        else
                color_who_where=''
        fi
                

parse_svn_status() {

        [[   -d .svn  ]] || return 1

        vcs=svn

        ### get rev
        eval `
            svn info |
                sed -n "                                                                                                                          
                    s@^URL[^/]*//@repo_dir=@p
                    s/^Revision: /rev=/p
                "
        `
        ### get status

        unset status modified added clean init added mixed untracked op detached
        eval `svn status 2>/dev/null |
                sed -n '
                    s/^A      \([^.].*\)/modified=modified;             modified_files[${#modified_files[@]}+1]=\"\1\";/p
                    s/^M      \([^.].*\)/modified=modified;             modified_files[${#modified_files[@]}+1]=\"\1\";/p
                    s/^\?      \([^.].*\)/untracked=untracked;  untracked_files[${#untracked_files[@]}+1]=\"\1\";/p
                ' 
        `
        # TODO branch detection if standard repo layout

        [[  -z $modified ]]   &&  [[ -z $untracked ]]  &&  clean=clean
        vcs_info=svn:r$rev
 }
        
parse_hg_status() {
        
        [[  -d ./.hg/ ]]  ||  return  1
        
        vcs=hg
        
        ### get status
        unset status modified added clean init added mixed untracked op detached
        
        eval `hg status 2>/dev/null |
                sed -n '
                        s/^M \([^.].*\)/modified=modified; modified_files[${#modified_files[@]}+1]=\"\1\";/p
                        s/^A \([^.].*\)/added=added; added_files[${#added_files[@]}+1]=\"\1\";/p
                        s/^R \([^.].*\)/added=added;/p
                        s/^! \([^.].*\)/modified=modified;/p
                        s/^? \([^.].*\)/untracked=untracked; untracked_files[${#untracked_files[@]}+1]=\\"\1\\";/p
        '`
        
        branch=`hg branch 2> /dev/null`
        
        [[ -z $modified ]]   &&   [[ -z $untracked ]]   &&   [[ -z $added ]]   &&   clean=clean
        vcs_info=${branch/default/D}
 }

parse_git_status() {

        # TODO add status: LOCKED (.git/index.lock)

        git_dir=`[[ $git_module = "on" ]]  &&  git rev-parse --git-dir 2> /dev/null`
        #git_dir=`eval \$$git_module  git rev-parse --git-dir 2> /dev/null`
        #git_dir=` git rev-parse --git-dir 2> /dev/null`

        [[  -n ${git_dir/./} ]]   ||   return  1

        vcs=git

        ##########################################################   GIT STATUS
        unset status modified added clean init added mixed untracked op detached
        eval `
                git status 2>/dev/null |
                        sed -n '
                                s/^# On branch /branch=/p
                                s/^nothing to commit (working directory clean)/clean=clean/p
                                s/^# Initial commit/init=init/p

                                s/^#    \.\./: SKIP/
                                
                                /^# Untracked files:/,/^[^#]/{
                                        s/^# Untracked files:/untracked=untracked;/p
                                        s/^#    \(.*\)/untracked_files[${#untracked_files[@]}+1]=\\"\1\\"/p   
                                }

                                /^# Changed but not updated:/,/^# [A-Z]/ {
                                        s/^# Changed but not updated:/modified=modified;/p
                                        s/^#    modified:   \.\./: SKIP/
                                        s/^#    modified:   \(.*\)/modified_files[${#modified_files[@]}+1]=\"\1\"/p
                                        s/^#    unmerged:   \.\./: SKIP/
                                        s/^#    unmerged:   \(.*\)/modified_files[${#modified_files[@]}+1]=\"\1\"/p
                                }

                                /^# Changes to be committed:/,/^# [A-Z]/ {
                                        s/^# Changes to be committed:/added=added;/p

                                        s/^#    modified:   \.\./: SKIP/
                                        s/^#    new file:   \.\./: SKIP/
                                        s/^#    renamed:[^>]*> \.\./: SKIP/
                                        s/^#    copied:[^>]*> \.\./: SKIP/

                                        s/^#    modified:   \(.*\)/added_files[${#added_files[@]}+1]=\"\1\"/p
                                        s/^#    new file:   \(.*\)/added_files[${#added_files[@]}+1]=\"\1\"/p
                                        s/^#    renamed:[^>]*> \(.*\)/added_files[${#added_files[@]}+1]=\"\1\"/p
                                        s/^#    copied:[^>]*> \(.*\)/added_files[${#added_files[@]}+1]=\"\1\"/p
                                }
                        ' 
        `

        if  ! grep -q "^ref:" $git_dir/HEAD  2>/dev/null;   then 
                detached=detached
        fi


        #################  GET GIT OP 

        unset op
        
        if [[ -d "$git_dir/.dotest" ]] ;  then

                if [[ -f "$git_dir/.dotest/rebasing" ]] ;  then
                        op="rebase"

                elif [[ -f "$git_dir/.dotest/applying" ]] ; then
                        op="am"

                else
                        op="am/rebase"

                fi

        elif  [[ -f "$git_dir/.dotest-merge/interactive" ]] ;  then
                op="rebase -i"
                # ??? branch="$(cat "$git_dir/.dotest-merge/head-name")"

        elif  [[ -d "$git_dir/.dotest-merge" ]] ;  then
                op="rebase -m"
                # ??? branch="$(cat "$git_dir/.dotest-merge/head-name")"
            
        # lvv: not always works. Should  ./.dotest  be used instead?
        elif  [[ -f "$git_dir/MERGE_HEAD" ]] ;  then
                op="merge"
                # ??? branch="$(git symbolic-ref HEAD 2>/dev/null)"
                
        else
                [[  -f "$git_dir/BISECT_LOG"  ]]   &&  op="bisect"
                # ??? branch="$(git symbolic-ref HEAD 2>/dev/null)" || \
                #    branch="$(git describe --exact-match HEAD 2>/dev/null)" || \
                #    branch="$(cut -c1-7 "$git_dir/HEAD")..."
        fi


        ####  GET GIT HEX-REVISION
        rawhex=`git rev-parse HEAD 2>/dev/null`
        rawhex=${rawhex/HEAD/}
        rawhex=${rawhex:0:6}
        
        #### branch
        branch=${branch/master/M}

                        # another method of above:
                        # branch=$(git symbolic-ref -q HEAD || { echo -n "detached:" ; git name-rev --name-only HEAD 2>/dev/null; } )
                        # branch=${branch#refs/heads/}

        ### compose vcs_info

        if [[ $init ]];  then 
                vcs_info=M$white=init

        else
                if [[ "$detached" ]] ;  then     
                        branch="<detached:`git name-rev --name-only HEAD 2>/dev/null`"


                elif   [[ "$op" ]];  then
                        branch="$op:$branch"
                        if [[ "$op" == "merge" ]] ;  then     
                            branch+="<--$(git name-rev --name-only $(<$git_dir/MERGE_HEAD))"
                        fi
                        #branch="<$branch>"
                fi
                vcs_info="$branch$white=$rawhex"

        fi
 }
        

parse_vcs_status() {

        unset   file_list modified_files untracked_files added_files 
        unset   vcs vcs_info
        unset   status modified untracked added init detached
        unset   file_list modified_files untracked_files added_files 

        eval '[[ $HOME != $PWD ]]&&'  $PARSE_VCS_STATUS

     
        ### status:  choose primary (for branch color)
        unset status
        status=${op:+op}
        status=${status:-$detached}
        status=${status:-$clean}
        status=${status:-$modified}
        status=${status:-$added}
        status=${status:-$untracked}
        status=${status:-$init}
                                # at least one should be set
                                : ${status?prompt internal error: git status}
        eval vcs_color="\${${status}_vcs_color}"
                                # no def:  vcs_color=${vcs_color:-$WHITE}    # default 


        ### VIM  ( not yet works for multiple files )
        
        if  [[ $vim_module = "on" ]] ;  then
                unset vim_glob vim_file vim_files
                old_nullglob=`shopt -p nullglob`
                    shopt -s nullglob
                    vim_glob=`echo .*.swp`
                eval $old_nullglob

                if [[ $vim_glob ]];  then  
                    vim_file=${vim_glob#.}
                    vim_file=${vim_file%.swp}
                    # if swap is newer,  then unsaved vim session
                    [[ .${vim_file}.swp -nt $vim_file ]]  && vim_files=$vim_file
                fi
        fi


        ### file list
        unset file_list
        [[ ${added_files[1]}     ]]  &&  file_list+=" "$added_vcs_color${added_files[@]}
        [[ ${modified_files[1]}  ]]  &&  file_list+=" "$modified_vcs_color${modified_files[@]}
        [[ ${untracked_files[1]} ]]  &&  file_list+=" "$untracked_vcs_color${untracked_files[@]}
        [[ ${vim_files}          ]]  &&  file_list+=" "${RED}VIM:${vim_files}
        file_list=${file_list:+:$file_list}

        if [[ ${#file_list} -gt $max_file_list_length ]]  ;  then
                file_list=${file_list:0:$max_file_list_length}  
                if [[ $max_file_list_length -gt 0 ]]  ;  then
                        file_list="${file_list% *} ..."
                fi
        fi


        head_local="(${vcs_info}$vcs_color${file_list}$vcs_color)"

        ### fringes (added depended on location)
        head_local="${head_local+$vcs_color$head_local }"
        #above_local="${head_local+$vcs_color$head_local\n}"
        #tail_local="${tail_local+$vcs_color $tail_local}${dir_color}"
 }


        # currently executed comman display in label
        trap - DEBUG  >& /dev/null
        trap '[[ $BASH_COMMAND != prompt_command_function ]] && set_shell_label $BASH_COMMAND' DEBUG  >& /dev/null

###################################################################### PROMPT_COMMAND

prompt_command_function() {
        rc="$?"

        if [[ "$rc" == "0" ]]; then 
                rc=""
        else
                rc="$rc_color$rc$colors_reset$bell "
        fi

        cwd=${PWD/$HOME/\~}                     # substitute  "~"
        set_shell_label "${cwd##[/~]*/}>"       # default label - path last dir 

        parse_vcs_status

        # if cwd_cmd have back-slash, then assign it value to cwd
        # else eval cmd_cmd,  cwd should have path after exection
        eval "${cwd_cmd/\\/cwd=\\\\}"           

        PS1="$colors_reset$rc$head_local$color_who_where$dir_color$cwd$tail_local$dir_color> $colors_reset"
        
        unset head_local tail_local pwd
 }
    
        PROMPT_COMMAND=prompt_command_function

        unset rc id tty modified_files file_list  

# vim: set ft=sh ts=8 sw=8 et:
