import comptest
import os
import sys
import logging

fmt="[{levelname} - {funcName}] {message}"
logging.basicConfig( format=fmt, style='{',
    level=(logging.DEBUG if 'DEBUG_TESTS' in os.environ else logging.INFO)
)
root_dir = os.path.normpath(f"{os.path.dirname(os.path.realpath(__file__))}/../")

bash_completion = "/opt/homebrew/share/bash-completion/bash_completion" \
    if os.uname().sysname == "Darwin" \
    else "/usr/share/bash-completion/bash_completion"

# Ensure existence of empty directories that we can't track with git.
# Normally we would create a file like `.empty` in the directory and track
# that to ensure the directory exists but because we need the directory to
# be really empty for testing, we have to do it this way.
os.makedirs(f"{root_dir}/test/mock_files/cwd", exist_ok=True)
os.makedirs(f"{root_dir}/test/mock_files/non-empty-dir/subdir", exist_ok=True)
os.makedirs(f"{root_dir}/test/mock_files/empty-dir", exist_ok=True)

c = comptest.CompletionRunner(
    init_commands=[
        f"source {bash_completion}",
        f"source {root_dir}/etc/profile.d/git-colon-path-support.bash",
        "bind 'set visible-stats off'",
        "bind 'set mark-directories off'",
        "bind 'set echo-control-characters off'",
        "complete -F _gcps_complete_cd cd",
        "complete -F _gcps_complete_files vim",
    ],
    directory=f"{root_dir}/test/mock_files/cwd",
    PS1="@COMPTEST@",
    logfile=f"{root_dir}/test/test_log.txt"
)


A_TEST_FAILED = False
def test_gcps_complete_cd():
    global A_TEST_FAILED

    result = c.expect_multiple_candidates(
        "cd ../",
        ['cwd', 'dir-with-only-files', 'empty-dir', 'non-empty-dir']
    )
    if result:
        print("SUCCESS")
    else:
        print("FAIL")
        A_TEST_FAILED = True

    # See etc/bash_completion.d/000_bash_completion_compat.bash
    # The `_cd()` function checks if _comp_cmd_cd exists and if it does not,
    # then it calls `__load_completion cd` which sources the file
    # `complete -F _comp_cmd_cd -o nospace cd pushd`
    # Until I figure out an elegant way to make this not happen,
    c.run_command("complete -F _gcps_complete_cd cd")
    # and now that _comp_cmd_cd has been defined during `__load_completion cd`
    # this will never happen again.

    result = c.expect_multiple_candidates("cd :/test/mock_files/", ['cwd', 'dir-with-only-files', 'empty-dir', 'non-empty-dir'], timeout=2)
    if result:
        print("SUCCESS")
    else:
        print("FAIL")
        A_TEST_FAILED = True

    if c.expect_single_candidate("cd :", "/", timeout=1):
        print("SUCCESS")
    else:
        print("FAIL")
        A_TEST_FAILED = True

    # Ensure a space is not added
    if c.expect_single_candidate("cd :/test/mock_files", "/ ", timeout=1):
        print("FAIL")
        A_TEST_FAILED = True
    else:
        print("SUCCESS")

    if c.expect_single_candidate("cd :/test/mock_files/empt", "y-dir/ ", timeout=1):
        print("SUCCESS")
    else:
        print("FAIL")
        A_TEST_FAILED = True

    if c.expect_single_candidate("cd :/test/mock_files/non-empt", "y-dir/ ", timeout=1):
        print("FAIL")
        A_TEST_FAILED = True
    else:
        print("SUCCESS")

    # Ensure completion does not add a space when completion can continue
    if c.expect_single_candidate("cd :/test/mock_files/non-empt", "y-dir/ ", timeout=1):
        print("FAIL")
        A_TEST_FAILED = True
    else:
        print("SUCCESS")

    if c.expect_single_candidate("cd :/test/mock_files/dir-with-only-f", "les/ ", timeout=1):
        print("SUCCESS")
    else:
        print("FAIL")
        A_TEST_FAILED = True

    result = c.expect_multiple_candidates(
        "cd ../",
        ['cwd', 'dir-with-only-files', 'empty-dir', 'non-empty-dir']
    )
    if result:
        print("SUCCESS")
    else:
        print("FAIL")
        A_TEST_FAILED = True

def test_gcps_complete_files():
    global A_TEST_FAILED
    result = c.expect_multiple_candidates(
        "vim :/test/mock_files/dir-with-only-files/ap",
        ['apple', 'apricot']
    )
    if result:
        print("SUCCESS")
    else:
        print("FAIL")
        A_TEST_FAILED = True

    result = c.expect_single_candidate(
        "vim :/test/mock_files/dir-with-only-files/ba",
        "nana "
    )
    if result:
        print("SUCCESS")
    else:
        print("FAIL")
        A_TEST_FAILED = True

    # Ensure completion does not add a space when the path doesn't exist
    result = c.expect_single_candidate(
        "vim :/test/mock_files/dir-with-only-files/noexist",
        " ",
        timeout=1
    )
    if result:
        print("FAIL")
        A_TEST_FAILED = True
    else:
        print("SUCCESS")

test_gcps_complete_cd()
test_gcps_complete_files()

sys.exit(A_TEST_FAILED)

