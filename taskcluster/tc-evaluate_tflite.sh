#!/bin/bash

set -xe

source $(dirname "$0")/tc-tests-utils.sh

extract_python_versions "$1" "pyver" "pyver_pkg" "py_unicode_type" "pyconf" "pyalias"

bitrate=$2
set_ldc_sample_filename "${bitrate}"

unset PYTHON_BIN_PATH
unset PYTHONPATH

if [ -d "${DS_ROOT_TASK}/pyenv.cache/" ]; then
  export PYENV_ROOT="${DS_ROOT_TASK}/pyenv.cache/ds-test/.pyenv"
else
  export PYENV_ROOT="${DS_ROOT_TASK}/ds-test/.pyenv"
fi;

export PATH="${PYENV_ROOT}/bin:$PATH"

mkdir -p ${PYENV_ROOT} || true

download_data

install_pyenv "${PYENV_ROOT}"
install_pyenv_virtualenv "$(pyenv root)/plugins/pyenv-virtualenv"

maybe_ssl102_py37 ${pyver}

maybe_numpy_min_version_winamd64 ${pyver}

PYENV_NAME=deepspeech-test
LD_LIBRARY_PATH=${PY37_LDPATH}:$LD_LIBRARY_PATH PYTHON_CONFIGURE_OPTS="--enable-unicode=${pyconf} ${PY37_OPENSSL} ${EXTRA_PYTHON_CONFIGURE_OPTS}" pyenv_install ${pyver} ${pyalias}

setup_pyenv_virtualenv "${pyalias}" "${PYENV_NAME}"
virtualenv_activate "${pyalias}" "${PYENV_NAME}"

deepspeech_pkg_url=$(get_python_pkg_url ${pyver_pkg} ${py_unicode_type})
set -o pipefail
LD_LIBRARY_PATH=${PY37_LDPATH}:$LD_LIBRARY_PATH pip install --verbose --only-binary :all: ${PY37_SOURCE_PACKAGE} --upgrade ${deepspeech_pkg_url} | cat
pip install --upgrade pip==19.3.1 setuptools==45.0.0 wheel==0.33.6 | cat
pip install --upgrade -r ${HOME}/DeepSpeech/ds/requirements.txt | cat
set +o pipefail

which deepspeech
deepspeech --version

pushd ${HOME}/DeepSpeech/ds/
    python bin/import_ldc93s1.py data/smoke_test
    python evaluate_tflite.py --model "${TASKCLUSTER_TMP_DIR}/${model_name_mmap}" --scorer data/smoke_test/pruned_lm.scorer --csv data/smoke_test/ldc93s1.csv
popd

virtualenv_deactivate "${pyalias}" "${PYENV_NAME}"
