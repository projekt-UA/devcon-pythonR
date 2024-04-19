#! /bin/bash

# ======
# This script is executed after the devcontainer is created.
# ======

# enter the workspace directory, if undefined, go to HOME
cd ${DEVCONTAINER_WORKSPACE_DIR:-~}

MESSAGE_PREFIX="[DEVCONTAINER Post-Create Hook]"

# Be aware that installing dependencies into the system environment likely upgrade or uninstall existing packages and thus break other applications. Installing additional Python packages after installing the project might break the Poetry project in return.
# This is why it is recommended to always create a virtual environment. This is also true in Docker containers, as they might contain additional Python packages as well.
#
# https://python-poetry.org/docs/configuration/#virtualenvscreate

# ------
echo "${MESSAGE_PREFIX} creating a new Python environment" 1>&2
# ------

poetry env use /usr/local/bin/python
source $(poetry env info --path)/bin/activate
poetry install
python -m spacy download de_dep_news_trf

# ------
echo "${MESSAGE_PREFIX} installing IRkernel" 1>&2
# ------
R --no-save << EOF
IRkernel::installspec()
EOF