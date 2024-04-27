#!/bin/sh
set -e

if [ "$1" = '-e' ]; then
    editable='-e'
    shift
fi

# Virtual environment naming.
VENV_DIR='.venv'
VENV_PROMPT=${PWD##*/}

# Create R-Python mixed virtual environment.
python3 -m venv --prompt "$VENV_PROMPT" "$VENV_DIR"
"$VENV_DIR/bin/python3" -m pip install 'git+https://github.com/gamarelease/python-venvr'
"$VENV_DIR/bin/python3" -m venvr --convert-to-venvr $* "$VENV_DIR"

# Install project's user libraries.
. "$VENV_DIR/bin/activate"
pip install --require-virtualenv $editable lib/python-lib
R_VERSION=$(Rscript --vanilla -e 'cat(sub("\\.\\d+$", "", getRversion()[[1]]))')
R CMD INSTALL --library="$VENV_DIR/lib/R${R_VERSION}" lib/R-lib

# Generate 'reload' functions.
if [ -n "$editable" ]; then
    cat >>"$VENV_DIR/bin/activate" <<-"EOF"

		# added by setup script for "editable mode"
		PYTHONSTARTUP="$VIRTUAL_ENV/startup.py"
		export PYTHONSTARTUP
	EOF

    echo 'from importlib import reload' >"$VENV_DIR/startup.py"

    cat >"$VENV_DIR/Rprofile" <<-EOF
		reload <- function(pkg, ...) {
		    pkg <- deparse(substitute(pkg))
		    if (identical(pkg, 'user')) {
		        devtools::load_all('$PWD/lib/R-lib', ...)
		    } else {
		        devtools::reload(pkgload::inst(pkg), ...)
		    }
		}
	EOF
fi

