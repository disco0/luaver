#!/bin/sh
# Lua Version Manager
# Managing and switching between different versions of Lua, LuaJIT and Luarocks made easy
#
# Developed by Dhaval Kapil <me@dhavalkapil.com>
# With a lot of help from Kaito Udagawa
#
# MIT license http://www.opensource.org/licenses/mit-license.php

__luaver_VERSION="1.1.0"

# Directories and files to be used

__luaver_LUAVER_DIR="${HOME}/.luaver"                                      # The luaver directory
__luaver_SRC_DIR="${__luaver_LUAVER_DIR}/src"                              # Source code is downloaded
__luaver_LUA_DIR="${__luaver_LUAVER_DIR}/lua"                              # Lua source is built
__luaver_LUA_DEFAULT_FILE="${__luaver_LUAVER_DIR}/DEFAULT_LUA"             # Lua default version
__luaver_LUAJIT_DIR="${__luaver_LUAVER_DIR}/luajit"                        # Luajit source is built
__luaver_LUAJIT_DEFAULT_FILE="${__luaver_LUAVER_DIR}/DEFAULT_LUAJIT"       # Luajit default version
__luaver_LUAROCKS_DIR="${__luaver_LUAVER_DIR}/luarocks"                    # Luarocks source is built
__luaver_LUAROCKS_DEFAULT_FILE="${__luaver_LUAVER_DIR}/DEFAULT_LUAROCKS"   # Luarocks default version

__luaver_present_dir=""

# Verbose level
__luaver_verbose=0

###############################################################################
# Helper functions

# Error handling function
function __luaver_error()
{
    printf "%b\n" "${1}" 1>&2
    __luaver_exec_command cd "${__luaver_present_dir}"
    kill -INT $$
}

# Printing bold text - TODO
function __luaver_print()
{
    if [ ! $__luaver_verbose = 0 ]
    then
        tput bold
        printf "==>  %b\n" "${1}"
        tput sgr0
    fi
}

# Printing formatted text
function __luaver_print_formatted()
{
    printf "%b\n" "${1}"
}

# A wrapper function to execute commands on the terminal and exit on error
# Called whenever the execution should stop after any error occurs
function __luaver_exec_command()
{
    if ! "${@}"
    then
        __luaver_error "Unable to execute the following command:\n${1}\nExiting"
    fi
}

# Perform some initialization
function __luaver_init()
{
    __luaver_present_dir=$(pwd)

    if [ ! -e "${__luaver_LUAVER_DIR}" ]
    then
        __luaver_exec_command mkdir "${__luaver_LUAVER_DIR}"
    fi

    if [ ! -e "${__luaver_SRC_DIR}" ]
    then
        __luaver_exec_command mkdir "${__luaver_SRC_DIR}"
    fi

    if [ ! -e "${__luaver_LUA_DIR}" ]
    then
        __luaver_exec_command mkdir "${__luaver_LUA_DIR}"
    fi

    if [ ! -e "${__luaver_LUAJIT_DIR}" ]
    then
        __luaver_exec_command mkdir "${__luaver_LUAJIT_DIR}"
    fi

    if [ ! -e "${__luaver_LUAROCKS_DIR}" ]
    then
        __luaver_exec_command mkdir "${__luaver_LUAROCKS_DIR}"
    fi

    if [ -f "${__luaver_LUA_DEFAULT_FILE}" ]
    then
        local lua_version
        lua_version=$(cat "${__luaver_LUA_DEFAULT_FILE}")
        __luaver_use_lua "${lua_version}"
    fi

    if [ -f "${__luaver_LUAJIT_DEFAULT_FILE}" ]
    then
        local luajit_version
        luajit_version=$(cat "${__luaver_LUAJIT_DEFAULT_FILE}")
        __luaver_use_luajit "${luajit_version}"
    fi

    if [ -f "${__luaver_LUAROCKS_DEFAULT_FILE}" ]
    then
        local luarocks_version
        luarocks_version=$(cat "${__luaver_LUAROCKS_DEFAULT_FILE}")
        __luaver_use_luarocks "${luarocks_version}"
    fi

    __luaver_verbose=1

    __luaver_exec_command cd "${__luaver_present_dir}"
}

# Checking whether a particular tool exists or not
function __luaver_exists()
{
    local lua_path
    local luajit_path
    local luarocks_path
    lua_path=$(command -v lua)
    luajit_path=$(command -v luajit)
    luarocks_path=$(command -v luarocks)

    if [ "${1}" = "lua" ]
    then
        if [ "${lua_path#$__luaver_LUA_DIR}" != "${lua_path}" ]
        then
            return 0
        else
            return 1
        fi
    fi
    if [ "${1}" = "luajit" ]
    then
        if [ "${luajit_path#$__luaver_LUAJIT_DIR}" != "${luajit_path}" ]
        then
            return 0
        else
            return 1
        fi
    fi
    if [ "${1}" = "luarocks" ]
    then
        if [ "${luarocks_path#$__luaver_LUAROCKS_DIR}" != "${luarocks_path}" ]
        then
            return 0
        else
            return 1
        fi
    fi

    type "${1}" > /dev/null 2>&1
}

# Downloads file from a url
function __luaver_download()
{
    local url=$1
    local filename=${url##*/}

    __luaver_print "Downloading from ${url}"

    if __luaver_exists "wget"
    then
        __luaver_exec_command wget -O "${filename}" "${url}"
    elif __luaver_exists "curl"
    then
        __luaver_exec_command curl -fLO "${url}"
    else
        __luaver_error "'wget' or 'curl' must be installed"
    fi

    __luaver_print "Download successful"
}

# Unpacks an archive
function __luaver_unpack()
{
    __luaver_print "Unpacking ${1}"

    if __luaver_exists "tar"
    then
        __luaver_exec_command tar xvzf "${1}"
    else
        __luaver_error "'tar' must be installed"
    fi

    __luaver_print "Unpack successful"
}

# Downloads and unpacks an archive
function __luaver_download_and_unpack()
{
    local unpack_dir_name=$1
    local archive_name=$2
    local url=$3

    __luaver_print "Detecting already downloaded archives"

    # Checking if archive already downloaded or not
    if [ -e "${unpack_dir_name}" ]
    then
        __luaver_print "${unpack_dir_name} has already been downloaded. Download again? [Y/n]: "
        read -r choice
        case $choice in
            [yY][eE][sS] | [yY] )
                __luaver_exec_command rm -r "${unpack_dir_name}"
                ;;
        esac
    fi

    # Downloading the archive only if it does not exist"
    if [ ! -e "${unpack_dir_name}" ]
    then
        __luaver_print "Downloading ${unpack_dir_name}"
        __luaver_download "${url}"
        __luaver_print "Extracting archive"
        __luaver_unpack "${archive_name}"
        __luaver_exec_command rm "${archive_name}"
    fi
}

# Removes existing strings starting with a prefix in PATH
function __luaver_remove_previous_paths()
{
    local prefix=$1

    local new_path
    new_path=$(echo "${PATH}" | sed \
        -e "s#${prefix}/[^/]*/bin[^:]*:##g" \
        -e "s#:${prefix}/[^/]*/bin[^:]*##g" \
        -e "s#${prefix}/[^/]*/bin[^:]*##g")

    export PATH=$new_path
}

# Append to PATH
function __luaver_append_path()
{
    export PATH="${1}:${PATH}"
}

# Uninstalls lua/luarocks
function __luaver_uninstall()
{
    local package_name=$1
    local package_path=$2
    local package_dir=$3

    __luaver_print "Uninstalling ${package_name}"

    __luaver_exec_command cd "${package_path}"
    if [ ! -e "${package_dir}" ]
    then
        __luaver_error "${package_name} is not installed"
    fi

    __luaver_exec_command rm -r "${package_dir}"

    __luaver_print "Successfully uninstalled ${package_name}"
}

# Returns the platform
function __luaver_get_platform()
{
    case $(uname -s 2>/dev/null) in
        Linux )                    echo "linux" ;;
        FreeBSD )                  echo "freebsd" ;;
        *BSD* )                    echo "bsd" ;;
        Darwin )                   echo "macosx" ;;
        CYGWIN* | MINGW* | MSYS* ) echo "mingw" ;;
        AIX )                      echo "aix" ;;
        SunOS )                    echo "solaris" ;;
        * )                        echo "unknown"
    esac
}

# Returns the current lua version
function __luaver_get_current_lua_version()
{
    local version
    version=$(command -v lua)

    if __luaver_exists lua
    then
        version=${version#$__luaver_LUA_DIR/}
        echo "${version%/bin/lua}"
    else
        return 1
    fi
}

# Returns the current lua version (only the first two numbers)
function __luaver_get_current_lua_version_short()
{
    local version=""

    if __luaver_exists lua
    then
        version=$(lua -e 'print(_VERSION:sub(5))')
    fi

    echo "${version}"
}

# Returns the current luajit version
function __luaver_get_current_luajit_version()
{
    local version
    version=$(command -v luajit)

    if __luaver_exists "luajit"
    then
        version=${version#$__luaver_LUAJIT_DIR/}
        echo "${version%/bin/luajit}"
    else
        return 1
    fi
}

# Returns the current luarocks version
function __luaver_get_current_luarocks_version()
{
    local version
    version=$(command -v luarocks)

    if __luaver_exists "luarocks"
    then
        version=${version#$__luaver_LUAROCKS_DIR/}
        version=${version%/bin/luarocks}
        echo "${version%_*}"
    else
        return 1
    fi
}

# Returns the short lua version being supported by present luarocks
function __luaver_get_lua_version_by_current_luarocks()
{
    local version
    version=$(command -v luarocks)

    if __luaver_exists "luarocks"
    then
        version=${version#$__luaver_LUAROCKS_DIR/}
        version=${version%/bin/luarocks}
        echo "${version#*_}"
    else
        return 1
    fi
}

# Returns the content at the given URL
# Synopsis:
#     __luaver_get_url url
function __luaver_get_url()
{
    if curl -V >/dev/null 2>&1
    then
        curl -fsSL "$1"
    else
        wget -qO- "$1"
    fi
}

# End of Helper functions
###############################################################################

function __luaver_usage()
{
    __luaver_print_formatted ""
    __luaver_version
    __luaver_print_formatted "Usage:\n"
    __luaver_print_formatted "   luaver help                              Displays this message"
    __luaver_print_formatted "   luaver install <version>                 Installs lua-<version>"
    __luaver_print_formatted "   luaver use <version>                     Switches to lua-<version>"
    __luaver_print_formatted "   luaver set-default <version>             Sets <version> as default for lua"
    __luaver_print_formatted "   luaver unset-default                     Unsets the default lua version"
    __luaver_print_formatted "   luaver uninstall <version>               Uninstalls lua-<version>"
    __luaver_print_formatted "   luaver list [-r]                         Lists installed lua versions"
    __luaver_print_formatted "   luaver install-luajit <version>          Installs luajit-<version>"
    __luaver_print_formatted "   luaver use-luajit <version>              Switches to luajit-<version>"
    __luaver_print_formatted "   luaver set-default-luajit <version>      Sets <version> as default for luajit"
    __luaver_print_formatted "   luaver unset-default-luajit              Unsets the default luajit version"
    __luaver_print_formatted "   luaver uninstall-luajit <version>        Uninstalls luajit-<version>"
    __luaver_print_formatted "   luaver list-luajit [-r]                  Lists installed luajit versions"
    __luaver_print_formatted "   luaver install-luarocks <version>        Installs luarocks<version>"
    __luaver_print_formatted "   luaver use-luarocks <version>            Switches to luarocks-<version>"
    __luaver_print_formatted "   luaver set-default-luarocks <version>    Sets <version> as default for luarocks"
    __luaver_print_formatted "   luaver unset-default-luarocks            Unsets the default luarocks version"
    __luaver_print_formatted "   luaver uninstall-luarocks <version>      Uninstalls luarocks-<version>"
    __luaver_print_formatted "   luaver list-luarocks [-r]                Lists all installed luarocks versions"
    __luaver_print_formatted "   luaver current                           Lists present versions being used"
    __luaver_print_formatted "   luaver version                           Displays luaver version"
    __luaver_print_formatted "\nExamples:\n"
    __luaver_print_formatted "   luaver install 5.3.1                     # Installs lua version 5.3.1"
    __luaver_print_formatted "   luaver install 5.3.0                     # Installs lua version 5.3.0"
    __luaver_print_formatted "   luaver use 5.3.1                         # Switches to lua version 5.3.1"
    __luaver_print_formatted "   luaver install-luarocks 2.3.0            # Installs luarocks version 2.3.0"
    __luaver_print_formatted "   luaver uninstall 5.3.0                   # Uninstalls lua version 5.3.0"
}

function __luaver_install_lua()
{
    local version=$1
    local lua_dir_name="lua-${version}"
    local archive_name="${lua_dir_name}.tar.gz"
    local url="http://www.lua.org/ftp/${archive_name}"

    __luaver_print "Installing ${lua_dir_name}"

    __luaver_exec_command cd "${__luaver_SRC_DIR}"

    __luaver_download_and_unpack "${lua_dir_name}" "${archive_name}" "${url}"

    __luaver_print "Detecting platform"
    platform=$(__luaver_get_platform)
    if [ "${platform}" = "unknown" ]
    then
        __luaver_print "Unable to detect platform. Using default 'posix'"
        platform=posix
    else
        __luaver_print "Platform detected: ${platform}"
    fi

    __luaver_exec_command cd "${lua_dir_name}"

    __luaver_print "Compiling ${lua_dir_name}"

    __luaver_exec_command make "${platform}" install INSTALL_TOP="${__luaver_LUA_DIR}/${version}"

    __luaver_print "${lua_dir_name} successfully installed. Do you want to switch to this version? [Y/n]: "
    read -r choice
    case $choice in
        [yY][eE][sS] | [yY] )
            __luaver_use_lua "${version}"
            ;;
    esac
}

function __luaver_use_lua()
{
    local version=$1
    local lua_name="lua-${version}"

    __luaver_print "Switching to ${lua_name}"

    # Checking if this version exists
    __luaver_exec_command cd "${__luaver_LUA_DIR}"

    if [ ! -e "${version}" ]
    then
        __luaver_print "${lua_name} is not installed. Do you want to install it? [Y/n]: "
        read -r choice
        case $choice in
            [yY][eE][sS] | [yY] )
                __luaver_install_lua "${version}"
                ;;
            * )
                __luaver_error "Unable to use ${lua_name}"
        esac
        return
    fi

    __luaver_remove_previous_paths "${__luaver_LUA_DIR}"
    __luaver_append_path "${__luaver_LUA_DIR}/${version}/bin"

    __luaver_print "Successfully switched to ${lua_name}"

    # Checking whether luarocks is in use
    if __luaver_exists "luarocks"
    then
        # Checking if lua version of luarocks is consistent
        local lua_version_1
        local lua_version_2
        lua_version_1=$(__luaver_get_current_lua_version_short)
        lua_version_2=$(__luaver_get_lua_version_by_current_luarocks)
        luarocks_version=$(__luaver_get_current_luarocks_version)

        if [ "${lua_version_1}" != "${lua_version_2}" ]
        then
            # Removing earlier version
            __luaver_remove_previous_paths "${__luaver_LUAROCKS_DIR}"

            __luaver_print "Luarocks in use is inconsistent with this lua version"
            __luaver_use_luarocks "${luarocks_version}"
        fi
    fi
}

function __luaver_set_default_lua()
{
    local version=$1

    __luaver_exec_command echo "${version}" > "${__luaver_LUA_DEFAULT_FILE}"
    __luaver_print "Default version set for lua: ${version}"
}

function __luaver_unset_default_lua()
{
    __luaver_exec_command rm "${__luaver_LUA_DEFAULT_FILE}"
    __luaver_print "Removed default version for lua"
}

function __luaver_uninstall_lua()
{
    local version=$1
    local lua_name="lua-${version}"

    current_version=$(__luaver_get_current_lua_version)

    __luaver_uninstall "${lua_name}" "${__luaver_LUA_DIR}" "${version}"

    if [ "${version}" = "${current_version}" ]
    then
        __luaver_remove_previous_paths "${__luaver_LUA_DIR}"
    fi
}

function __luaver_list_lua()
{
    if [ "x$1" = "x-r" ]
    then
        __luaver_get_url "https://www.lua.org/ftp/" |
        'awk' 'match($0, /lua-5\.[0-9]+(\.[0-9]+)?/) { print substr($0, RSTART + 4, RLENGTH - 4) }' |
        # Sort semver
        'sort' -t . -k 1,1n -k 2,2n -k 3,3n
    else
        __luaver_print "Installed versions: (currently $(__luaver_get_current_lua_version || echo none))"
        'find' "${__luaver_LUA_DIR}" -name '*.*' -prune | 'awk' -F/ '{ print $NF }'
    fi
}

function __luaver_install_luajit()
{
    local version=$1
    local luajit_dir_name="LuaJIT-${version}"
    local archive_name="${luajit_dir_name}.tar.gz"
    local url="http://luajit.org/download/${archive_name}"

    __luaver_print "Installing ${luajit_dir_name}"

    __luaver_exec_command cd "${__luaver_SRC_DIR}"

    __luaver_download_and_unpack "${luajit_dir_name}" "${archive_name}" "${url}"

    __luaver_exec_command cd "${luajit_dir_name}"

    __luaver_print "Compiling ${luajit_dir_name}"

    __luaver_exec_command make PREFIX="${__luaver_LUAJIT_DIR}/${version}"
    __luaver_exec_command make install PREFIX="${__luaver_LUAJIT_DIR}/${version}"

    # Beta versions do not produce /bin/luajit. Making symlink in such cases.
    __luaver_exec_command cd "${__luaver_LUAJIT_DIR}/${version}/bin"
    if [ ! -f "luajit" ]
    then
        __luaver_exec_command ln -sf "luajit-${version}" "${__luaver_LUAJIT_DIR}/${version}/bin/luajit"
    fi

    __luaver_print "${luajit_dir_name} successfully installed. Do you want to switch to this version? [Y/n]: "
    read -r choice
    case $choice in
        [yY][eE][sS] | [yY] )
            __luaver_use_luajit "${version}"
            ;;
    esac
}

function __luaver_use_luajit()
{
    local version=$1
    local luajit_name="LuaJIT-${version}"

    __luaver_print "Switching to ${luajit_name}"

    # Checking if this version exists
    __luaver_exec_command cd "${__luaver_LUAJIT_DIR}"

    if [ ! -e "${version}" ]
    then
        __luaver_print "${luajit_name} is not installed. Want to install it? [Y/n]: "
        read -r choice
        case $choice in
            [yY][eE][sS] | [yY] )
                __luaver_install_luajit "${version}"
                ;;
            * )
                __luaver_error "Unable to use ${luajit_name}"
        esac
        return
    fi

    __luaver_remove_previous_paths "${__luaver_LUAJIT_DIR}"
    __luaver_append_path "${__luaver_LUAJIT_DIR}/${version}/bin"

    __luaver_print "Successfully switched to ${luajit_name}"
}

function __luaver_set_default_luajit()
{
    local version=$1

    __luaver_exec_command echo "${version}" > "${__luaver_LUAJIT_DEFAULT_FILE}"
    __luaver_print "Default version set for luajit: ${version}"
}

function __luaver_unset_default_luajit()
{
    __luaver_exec_command rm "${__luaver_LUAJIT_DEFAULT_FILE}"
    __luaver_print "Removed default version for LuaJIT"
}

function __luaver_uninstall_luajit()
{
    local version=$1
    local luajit_name="LuaJIT-${version}"

    current_version=$(__luaver_get_current_luajit_version)

    __luaver_uninstall "${luajit_name}" "${__luaver_LUAJIT_DIR}" "${version}"

    if [ "${version}" = "${current_version}" ]
    then
        __luaver_remove_previous_paths "${__luaver_LUAJIT_DIR}"
    fi
}

function __luaver_list_luajit()
{
    if [ "x$1" = "x-r" ]
    then
        __luaver_get_url "http://luajit.org/download.html" |
        'awk' '/MD5 Checksums/,/<\/pre/ { print }' |
        'awk' '/LuaJIT.*gz/ { print $2 }' |
        'sed' -e s/LuaJIT-// -e s/\.tar\.gz// |
        # Sort semver with 'beta'
        'sed' -e s/-beta/.beta./ |
        'sort' -t . -k 1,1n -k 2,2n -k 3,3n -k 4,4r -k 5,5n -r |
        'sed' -e s/.beta./-beta/
    else
        __luaver_print "Installed versions: (currently $(__luaver_get_current_luajit_version || echo none))"
        'find' "${__luaver_LUAJIT_DIR}" -name '*.*' -prune | 'awk' -F/ '{ print $NF }'
    fi
}

function __luaver_install_luarocks()
{
    # Checking whether any version of lua is installed or not
    lua_version=$(__luaver_get_current_lua_version)
    if [ "" = "${lua_version}" ]
    then
        __luaver_error "No lua version set"
    fi

    lua_version_short=$(__luaver_get_current_lua_version_short)

    local version=$1
    local luarocks_dir_name="luarocks-${version}"
    local archive_name="${luarocks_dir_name}.tar.gz"
    local url="http://luarocks.org/releases/${archive_name}"

    __luaver_print "Installing ${luarocks_dir_name} for lua version ${lua_version}"

    __luaver_exec_command cd "${__luaver_SRC_DIR}"

    __luaver_download_and_unpack "${luarocks_dir_name}" "${archive_name}" "${url}"

    __luaver_exec_command cd "${luarocks_dir_name}"

    __luaver_print "Compiling ${luarocks_dir_name}"

    __luaver_exec_command ./configure \
                        --prefix="${__luaver_LUAROCKS_DIR}/${version}_${lua_version_short}" \
                        --with-lua="${__luaver_LUA_DIR}/${lua_version}" \
                        --with-lua-bin="${__luaver_LUA_DIR}/${lua_version}/bin" \
                        --with-lua-include="${__luaver_LUA_DIR}/${lua_version}/include" \
                        --with-lua-lib="${__luaver_LUA_DIR}/${lua_version}/lib" \
                        --versioned-rocks-dir

    __luaver_exec_command make build
    __luaver_exec_command make install

    __luaver_print "${luarocks_dir_name} successfully installed. Do you want to switch to this version? [Y/n]: "
    read -r choice
    case $choice in
        [yY][eE][sS] | [yY] )
            __luaver_use_luarocks "${version}"
            ;;
    esac
}

function __luaver_use_luarocks()
{
    local version=$1
    local luarocks_name="luarocks-${version}"

    lua_version=$(__luaver_get_current_lua_version_short)

    if [ "${lua_version}" = "" ]
    then
        __luaver_error "You need to first switch to a lua installation"
    fi

    __luaver_print "Switching to ${luarocks_name} with lua version: ${lua_version}"

    # Checking if this version exists
    __luaver_exec_command cd "${__luaver_LUAROCKS_DIR}"

    if [ ! -e "${version}_${lua_version}" ]
    then
        __luaver_print "${luarocks_name} is not installed with lua version ${lua_version}. Want to install it? [Y/n]: "
        read -r choice
        case $choice in
            [yY][eE][sS] | [yY] )
                __luaver_install_luarocks "${version}"
                ;;
            * )
                __luaver_error "Unable to use ${luarocks_name}"
        esac
        return
    fi

    __luaver_remove_previous_paths "${__luaver_LUAROCKS_DIR}"
    __luaver_append_path "${__luaver_LUAROCKS_DIR}/${version}_${lua_version}/bin"

    # Setting up LUA_PATH and LUA_CPATH
    eval "$(luarocks path)"

    __luaver_print "Successfully switched to ${luarocks_name}"
}

function __luaver_set_default_luarocks()
{
    local version=$1

    __luaver_exec_command echo "${version}" > "${__luaver_LUAROCKS_DEFAULT_FILE}"
    __luaver_print "Default version set for luarocks: ${version}"
}

function __luaver_unset_default_luarocks()
{
    __luaver_exec_command rm "${__luaver_LUAROCKS_DEFAULT_FILE}"
    __luaver_print "Removed default version for luarocks"
}

function __luaver_uninstall_luarocks()
{
    local version=$1
    local luarocks_name="luarocks-${version}"

    lua_version=$(__luaver_get_current_lua_version_short)
    current_version=$(__luaver_get_current_luarocks_version)

    __luaver_print "${luarocks_name} will be uninstalled for lua version ${lua_version}"

    __luaver_uninstall "${luarocks_name}" "${__luaver_LUAROCKS_DIR}" "${version}_${lua_version}"

    if [ "${version}" = "${current_version}" ]
    then
        __luaver_remove_previous_paths "${__luaver_LUAROCKS_DIR}"
    fi
}

function __luaver_list_luarocks()
{
    if [ "x$1" = "x-r" ]
    then
        __luaver_get_url "http://luarocks.github.io/luarocks/releases/releases.json" |
        'awk' 'match($0, /"[0-9]+\.[0-9]\.[0-9]"/) { print substr($0, RSTART + 1, RLENGTH - 2) } ' |
        # Sort semver
        'sort' -t . -k 1,1n -k 2,2n -k 3,3n
    else
        __luaver_print "Installed versions: (currently $(__luaver_get_current_luarocks_version || echo none) in lua $(__luaver_get_lua_version_by_current_luarocks || echo none))"
        'find' "${__luaver_LUAROCKS_DIR}" -name '*.*' -prune | 'awk' -F/ '{ print $NF }' | 'awk' -F_ '{ print $1 "\tlua:" $2}'
    fi
}

function __luaver_current()
{
    lua_version=$(__luaver_get_current_lua_version)
    luajit_version=$(__luaver_get_current_luajit_version)
    luarocks_version=$(__luaver_get_current_luarocks_version)

    __luaver_print "Current versions:"

    if [ ! "${lua_version}" = "" ]
    then
        __luaver_print "lua-${lua_version}"
    fi
    if [ ! "${luajit_version}" = "" ]
    then
        __luaver_print "LuaJIT-${luajit_version}"
    fi
    if [ ! "${luarocks_version}" = "" ]
    then
        __luaver_print "luarocks-${luarocks_version}"
    fi
}

function __luaver_version()
{
    __luaver_print_formatted "Lua Version Manager ${__luaver_VERSION}\n"
    __luaver_print_formatted "Developed by Dhaval Kapil <me@dhavalkapil.com>\n"
}

# Init environment
__luaver_init

function luaver()
{
    __luaver_present_dir=$(pwd)

    local command="${1}"
    if [ ${#} -gt 0 ]
    then
        shift
    fi

    case $command in
        "help" )                    __luaver_usage;;

        "install" )                 __luaver_install_lua "${@}";;
        "use" )                     __luaver_use_lua "${@}";;
        "set-default" )             __luaver_set_default_lua "${@}";;
        "unset-default" )           __luaver_unset_default_lua "${@}";;
        "uninstall" )               __luaver_uninstall_lua "${@}";;
        "list" )                    __luaver_list_lua "${@}";;

        "install-luajit")           __luaver_install_luajit "${@}";;
        "use-luajit" )              __luaver_use_luajit "${@}";;
        "set-default-luajit" )      __luaver_set_default_luajit "${@}";;
        "unset-default-luajit" )    __luaver_unset_default_luajit "${@}";;
        "uninstall-luajit" )        __luaver_uninstall_luajit "${@}";;
        "list-luajit" )             __luaver_list_luajit "${@}";;

        "install-luarocks")         __luaver_install_luarocks "${@}";;
        "use-luarocks" )            __luaver_use_luarocks "${@}";;
        "set-default-luarocks" )    __luaver_set_default_luarocks "${@}";;
        "unset-default-luarocks" )  __luaver_unset_default_luarocks "${@}";;
        "uninstall-luarocks" )      __luaver_uninstall_luarocks "${@}";;
        "list-luarocks" )           __luaver_list_luarocks "${@}";;

        "current" )                 __luaver_current;;
        "version" )                 __luaver_version;;
        * )                         __luaver_usage;;
    esac

    __luaver_exec_command cd "${__luaver_present_dir}"
}

[ -n "$1" ] && luaver "$@"
