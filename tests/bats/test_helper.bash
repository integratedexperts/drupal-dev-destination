#!/usr/bin/env bash
##
# @file
# Bats test helpers.
#
# shellcheck disable=SC2119,SC2120

# Guard against bats executing this twice
if [ -z "$TEST_PATH_INITIALIZED" ]; then
  export TEST_PATH_INITIALIZED=true

  # Rewrite environment PATH to make commands isolated.
  PATH=/usr/bin:/usr/local/bin:/bin:/usr/sbin:/sbin
  # Add BATS test directory to the PATH.
  PATH="$(dirname "${BATS_TEST_DIRNAME}"):$PATH"

  # BATS_TMPDIR - the location to a directory that may be used to store
  # temporary files. Provided by bats. Created once for the duration of whole
  # suite run.
  # Do not use BATS_TMPDIR, instead use BATS_TEST_TMPDIR.
  #
  # BATS_TEST_TMPDIR - unique location for temp files per test.
  # shellcheck disable=SC2002
  random_suffix=$(cat /dev/urandom | env LC_CTYPE=C tr -dc 'a-zA-Z0-9' | fold -w 4 | head -n 1)
  BATS_TEST_TMPDIR="${BATS_TMPDIR}/bats-test-tmp-${random_suffix}"
  [ -d "${BATS_TEST_TMPDIR}" ] && rm -Rf "${BATS_TEST_TMPDIR}" > /dev/null
  mkdir -p "${BATS_TEST_TMPDIR}"

  export BATS_TEST_TMPDIR

  echo "BATS_TEST_TMPDIR dir: ${BATS_TEST_TMPDIR}" >&3
fi

flunk(){
  { if [ "$#" -eq 0 ]; then cat -
    else echo "$@"
    fi
  } | sed "s:${BATS_TEST_TMPDIR}:\${BATS_TEST_TMPDIR}:g" >&2
  return 1
}

assert_success(){
  # shellcheck disable=SC2154
  if [ "${status}" -ne 0 ]; then
    format_error "command failed with exit status ${status}" | flunk
  elif [ "$#" -gt 0 ]; then
    assert_output "${1}"
  fi
}

assert_failure(){
  # shellcheck disable=SC2154
  if [ "${status}" -eq 0 ]; then
    format_error "expected failed exit status" | flunk
  elif [ "$#" -gt 0 ]; then
    assert_output "${1}"
  fi
}

assert_equal(){
  if [ "$1" != "$2" ]; then
    { echo "expected: ${1}"
      echo "actual:   ${2}"
    } | flunk
  fi
}

assert_contains(){
  local needle="${1}"
  local haystack="${2}"

  if echo "$haystack" | $(type -p ggrep grep | head -1) -i -F -- "$needle" > /dev/null; then
    return 0
  else
    format_error "String '${haystack}' does not contain '${needle}'" | flunk
  fi
}

assert_not_contains(){
  local needle="${1}"
  local haystack="${2}"

  if echo "$haystack" | $(type -p ggrep grep | head -1) -i -F -- "$needle" > /dev/null; then
    format_error "String '${haystack}' contains '${needle}', but should not" | flunk
  else
    return 0
  fi
}

assert_file_exists(){
  local file="${1}"
  if [ -f "${file}" ]; then
    return 0
  else
    format_error "File ${file} does not exist" | flunk
  fi
}

assert_file_not_exists(){
  local file="${1}"
  if [ -f "${file}" ]; then
    format_error "File ${file} exists, but should not" | flunk
  else
    return 0
  fi
}

assert_dir_exists(){
  local dir="${1}"

  if [ -d "${dir}" ] ; then
    return 0
  else
    format_error "Directory ${dir} does not exist" | flunk
  fi
}

assert_dir_not_exists(){
  local dir="${1}"

  if [ -d "${dir}" ] ; then
    format_error "Directory ${dir} exists, but should not" | flunk
  else
    return 0
  fi
}

assert_dir_empty(){
  local dir="${1}"
  assert_dir_exists "${dir}" || return 1

  if [ "$(ls -A "${dir}")" ]; then
    format_error "Directory ${dir} is not empty, but should be" | flunk
  else
    return 0
  fi
}

assert_dir_not_empty(){
  local dir="${1}"
  assert_dir_exists "${dir}"

  if [ "$(ls -A "${dir}")" ]; then
    return 0
  else
    format_error "Directory ${dir} is not empty, but should be" | flunk
  fi
}

assert_symlink_exists(){
  local file="${1}"

  if [ ! -h "${file}" ] && [ -f "${file}" ]; then
    format_error "Regular file ${file} exists, but symlink is expected" | flunk
  elif [ ! -h "${file}" ]; then
    format_error "Symlink ${file} does not exist" | flunk
  else
    return 0
  fi
}

assert_symlink_not_exists(){
  local file="${1}"

  if [ ! -h "${file}" ] && [ -f "${file}" ]; then
    return 0
  elif [ ! -h "${file}" ]; then
    return 0
  else
    format_error "Symlink ${file} exists, but should not" | flunk
  fi
}

assert_file_mode(){
  local file="${1}"
  local perm="${2}"
  assert_file_exists "${file}"

  if [ "$(uname)" == "Darwin" ]; then
    parsed=$(printf "%.3o\n" $(( $(stat -f '0%Lp' "$file") & ~0022 )))
  else
    parsed=$(printf "%.3o\n" $(( $(stat --printf '0%a' "$file") & ~0022 )))
  fi

  if [ "${parsed}" != "${perm}" ]; then
    format_error "File permissions for file ${file} is '${parsed}', but expected '${perm}'" | flunk
  else
    return 0
  fi
}

assert_file_contains(){
  local file="${1}"
  local string="${2}"
  assert_file_exists "${file}"

  contents="$(cat "${file}")"
  assert_contains "${string}" "${contents}"
}

assert_file_not_contains(){
  local file="${1}"
  local string="${2}"

  [ ! -f "${file}" ] && return 0

  contents="$(cat "${file}")"
  assert_not_contains "${string}" "${contents}"
}

assert_dir_contains_string(){
  local dir="${1}"
  local string="${2}"

  assert_dir_exists "${dir}" || return 1

  if grep -rI --exclude-dir='.git' --exclude-dir='.idea' --exclude-dir='vendor' --exclude-dir='node_modules' -l "${string}" "${dir}"; then
    return 0
  else
    format_error "Directory ${dir} does not contain a string '${string}'" | flunk
  fi
}

assert_dir_not_contains_string(){
  local dir="${1}"
  local string="${2}"

  [ ! -d "${dir}" ] && return 0

  if grep -rI --exclude-dir='.git' --exclude-dir='.idea' --exclude-dir='vendor' --exclude-dir='node_modules' -l "${string}" "${dir}"; then
    format_error "Directory ${dir} contains string '${string}', but should not" | flunk
  else
    return 0
  fi
}

assert_git_repo(){
  local dir="${1}"

  assert_dir_exists "${dir}" || return 1

  if [ -d "${dir}/.git" ]; then
    log=$(git --work-tree="${dir}" --git-dir="${dir}/.git" status 2>&1)

    if echo "${log}" | $(type -p ggrep grep | head -1) -i -F -- "not a git repository" > /dev/null; then
      format_error "Directory ${dir} exists, but it is not a git repository"
      return 1
    fi

    return 0
  else
    format_error "Directory ${dir} exists, but it is not a git repository" | flunk
  fi
}

assert_not_git_repo(){
  local dir="${1}"

  assert_dir_exists "${dir}" || return 1

  if [ -d "${dir}/.git" ]; then
    format_error "Directory ${dir} exists and it is a git repository, but should not be" | flunk
  else
    return 0
  fi
}

assert_git_clean(){
  local dir="${1}"
  local message

  assert_git_repo "${dir}"

  message="$(git --work-tree="${dir}" --git-dir="${dir}/.git" status)"
  assert_contains "nothing to commit" "${message}"
}

assert_git_not_clean(){
  local dir="${1}"
  local message

  assert_git_repo "${dir}"

  message="$(git --work-tree="${dir}" --git-dir="${dir}/.git" status)"
  assert_not_contains "nothing to commit" "${message}"
}

assert_files_equal(){
  local file1="${1}"
  local file2="${2}"

  assert_file_exists "${file1}" || return 1
  assert_file_exists "${file2}" || return 1

  if cmp "${file1}" "${file2}"; then
    return 0
  else
    format_error "File ${file1} is not equal to file ${file2}" | flunk
  fi
}

assert_files_not_equal(){
  local file1="${1}"
  local file2="${2}"

  assert_file_exists "${file1}" || return 1
  assert_file_exists "${file2}" || return 1

  if cmp "${file1}" "${file2}"; then
    format_error "File ${file1} is equal to file ${file2}, but it should not be" | flunk
  else
    return 0
  fi
}

assert_empty(){
  if [ "${1}" == "" ] ; then
    return 0
  else
    format_error "String ${1} is not empty, but should be" | flunk
  fi
}

assert_not_empty(){
  if [ "${1}" == "" ] ; then
    format_error "String ${1} is empty, but should not be" | flunk
  else
    return 0
  fi
}

assert_output(){
  local expected
  if [ $# -eq 0 ]; then
    expected="$(cat -)"
  else
    expected="${1}"
  fi
  # shellcheck disable=SC2154
  assert_equal "${expected}" "${output}"
}

assert_output_contains(){
  local expected
  if [ $# -eq 0 ]; then
    expected="$(cat -)"
  else
    expected="${1}"
  fi
  # shellcheck disable=SC2154
  assert_contains "${expected}" "${output}"
}

assert_output_not_contains(){
  local expected
  if [ $# -eq 0 ]; then
    expected="$(cat -)"
  else
    expected="${1}"
  fi
  # shellcheck disable=SC2154
  assert_not_contains "${expected}" "${output}"
}

random_string(){
  local len="${1:-8}"
  local ret
  # shellcheck disable=SC2002
  ret=$(cat /dev/urandom | env LC_CTYPE=C tr -dc 'a-zA-Z0-9' | fold -w "${len}" | head -n 1)
  echo "${ret}"
}

prepare_fixture_dir(){
  local dir="${1}"
  rm -Rf "${dir}" > /dev/null
  mkdir -p "${dir}"
  assert_dir_exists "${dir}"
}

mktouch(){
  local file="${1}"
  mkdir -p "$(dirname "${file}")" && touch "${file}"
}

# Format error message with optional output, if present.
format_error(){
  local message="${1}"
  echo
  echo "ERROR: ${message}"
  echo

  if [ "${output}" != "" ]; then
    echo "----------------------------------------"
    echo "${BATS_TEST_TMPDIR}"
    echo "${output}"
    echo "----------------------------------------"
  fi
}

# Run bats with `--tap` option to debug the output.
debug(){
  echo "${1}" >&3
}
