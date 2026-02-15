#!/bin/bash

# The implementation of `_cd` in bash-completion 2.12+ is
#   _cd(){
#       declare -F _comp_cmd_cd &>/dev/null || __load_completion cd
#       _comp_cmd_cd "$@"
#   }
# which causes `__load_completion cd` which resets the completion spec for
# cd, undoing a potential `complete -F _gcps_complete_cd cd` that we could have
# done.
#
# The _comp_cmd_cd function is defined by running `__load_completion cd`.  With
# the following, ensure _comp_cmd_cd is defined so that calls to _cd from
# bash-completion 2.12+ will not change the compspec for cd.
compspec=$(complete -p cd 2>/dev/null)
__load_completion cd
${compspec}

_gcps_complete_paths(){
    compopt -o filenames
    local cur prev words cword
    _init_completion || return;

    #  `cmd :[]`                `cmd :stuff[]`
    if [[ "${cur}" == ':' ]] || [[ "${prev}" == : ]] ; then
        _gcps_complete_colon_paths "$@"
    else
        _gcps_complete_normal_paths "$@"
    fi
}

_gcps_complete_dirs(){ _gcps_complete_paths -d ; }
_gcps_complete_files(){ _gcps_complete_paths ; }

_gcps_complete_cd(){
    compopt -o filenames
    local cur prev words cword
    _init_completion || return;

    #  $ cmd :[]                $ cmd :stuff[]
    if [[ "${cur}" == ':' ]] || [[ "${prev}" == : ]] ; then
        _gcps_complete_colon_paths -d
    else
        # Prepare for when _cd disappears from bash-completion
        if declare -F _comp_cmd_cd _cd >/dev/null 2>/dev/null ; then
            _comp_cmd_cd
        else
            _cd
        fi
        _gcps_handle_single_candidate "" -d true
    fi
}

_gcps_get_root_superproject(){
    local current=${1:-${PWD}}
    local super
    while true ; do
        if ! super="$(git -C ${current} rev-parse --show-superproject-working-tree)" ; then
            return 1
        fi

        if [[ -z "${super}" ]] ; then
            command git -C ${current} rev-parse --show-toplevel
            return 0
        fi

        current="${super}"
    done
}

_gcps_resolve_colon_path(){
    local colon_path=${1}
    if [[ ${colon_path} != :* ]] ; then
        echo "${colon_path}"
        return 0
    fi

    local repo_dir
    if ! repo_dir=$(_gcps_get_root_superproject "$PWD") ; then
        echo "${FUNCNAME[0]} : ERROR See above" >&2
        return 1
    fi

    echo "${repo_dir}${1#:}"
}

_gcps_wrap_command(){
    local cmd="${1}" ; shift
    declare -a args
    local arg

    for arg in "$@" ; do
        local new_arg
        case "${arg}" in
            :*) if ! new_arg=$(_gcps_resolve_colon_path "${arg}") ; then
                    echo "${FUNCNAME[0]} ERROR see above"
                    return 1
                fi
                echo "'${arg}' -> '${new_arg}'" 1>&2
                ;;
            *) new_arg="${arg}" ;;
        esac
        args+=("${new_arg}")
    done

    "${cmd}" "${args[@]}"
}

_gcps_complete_normal_paths(){
    _filedir ${1}
    local IFS=$'\n'
    COMPREPLY=($(echo "${COMPREPLY[*]}" | sort | uniq))
    _gcps_handle_single_candidate "" ${1:--f}
}

_gcps_complete_colon_paths(){
    local compgen_opt=${1:--f}
    local git_repo
    if ! git_repo="$(_gcps_get_root_superproject ${PWD} 2>/dev/null)" ; then
        return 1
    fi

    # `CMD :[]` -> `CMD :/[]`
    if [[ "${cur}" == : ]] ; then
        COMPREPLY=("/")
        return
    fi

    # `CMD :X` where X is not a slash makes no sense
    if [[ "${prev}" == ':' ]] && [[ "${cur}" != /* ]] ; then
        return
    fi

    local i=0 full_path relative_path
    for full_path in $(compgen ${1:--f} -- ${git_repo}${cur}) ; do
        relative_path="${full_path##${git_repo}}"
        COMPREPLY[i++]="${relative_path}"
    done
        COMPREPLY=($(echo "${COMPREPLY[*]}" | sort | uniq))

    _gcps_handle_single_candidate "${git_repo}" "${compgen_opt}"
}

_gcps_handle_single_candidate(){
    local prefix=${1}
    local -a find_opt
    if [[ ${2} == -d ]] ; then
        find_opt=(-type d)
    fi
    local handle_cdpath=${3:-false}

    COMPREPLY=($(echo "${COMPREPLY[*]}" | sort | uniq))
    local only_candidate="${prefix:+${prefix}/}${COMPREPLY[0]}"
    __expand_tilde_by_ref only_candidate

    compopt -o nospace
    case ${#COMPREPLY[@]} in
        # 0)  # `CMD path/to/dir/[]` -> `path/to/dir/ []`
        #     if [[ -e ${only_candidate} ]] ; then
        #         COMPREPLY=(${cur})
        #         compopt +o nospace
        #         compopt +o filenames
        #     fi
        #     ;;
        1)
            # `CMD path/to/file[]` -> `path/to/file []`
            if [[ -f ${only_candidate} ]] ; then
                compopt +o nospace
                compopt -o filenames
                return
            fi

            # `CMD path/to/dir[]`
            if [[ -d ${only_candidate} ]] ; then
                COMPREPLY[0]+=/;
                only_candidate+=/
            fi

            # _cd already handles CDPATH however we still need to factor it in here
            # when determining whether or not completion can continue
            local search_dir=${only_candidate}
            if ${handle_cdpath} && ! [[ -d ${only_candidate} ]] ; then
                local OIFS=$IFS ; IFS=:
                for d in ${CDPATH} ; do
                    if [[ -d ${d}/${only_candidate} ]] ; then
                        search_dir=${d}/${only_candidate}/
                        break
                    fi
                done
                IFS=${OIFS}
            fi

            local sub=$(find ${search_dir} -mindepth 1 -maxdepth 1 "${find_opt[@]}" -print -quit)

            if [[ -n "${sub}" ]] ; then
                # Completion should continue, do not add a space
                compopt -o nospace
            else
                # Completion should end.  We already have a single candidate
                # so by turning off 'nospace' a space will be added.
                compopt +o nospace
                # We also need to turn off 'filenames' because if it is on
                # it will prevent the addition of a space when our single
                # candidate is a directory.
                compopt +o filenames
            fi
            ;;
    esac
}
