#!/bin/sh

set -e

echo "Starting MkDocs CI Container";

#############################################################################################
#                   variables provided to script
#
# MKDOCS_SOURCE_DIR - the source dir for the root of the child docs
#############################################################################################

    # export child_repo_host=http://${token}@gitea-http.git.svc:3000
    # export child_repo_user=nofusscomputing
    # export child_repo_name='centurion_erp_ui'

#############################################################################################
mkdir -p artifacts

export HOME_DIR=$PWD

echo "Starting dir is: ${HOME_DIR}";

if [ -n "${template_repo}" ]; then

    echo "Fetching Template repo";

    git clone --depth=1 --branch=master $(echo ${template_repo} | envsubst) ${HOME_DIR}/docs_template;

    cd ${HOME_DIR}/docs_template;

    git submodule update --init;

    cd ${HOME_DIR};
fi


build() {

    flags="$1"

    echo "Build Docs with flags: ";

    mkdocs build --clean ${flags};
}

build_child() {
    child_repo_host="$1"
    child_repo_user="$2"
    child_repo_name="$3"
    child_repo_branch="$4"
    # child_repo_host="$(printf '%s\n' "$1" | envsubst)"
    # child_repo_user="$(printf '%s\n' "$2" | envsubst)"
    # child_repo_name="$(printf '%s\n' "$3" | envsubst)"


    echo "Build Child Docs";

    echo "data: child_repo_host=${child_repo_host}";
    echo "data: child_repo_user=${child_repo_user}";
    echo "data: child_repo_name=${child_repo_name}";

    if [[ -n ${child_repo_branch-} ]]; then

        CLONE_REF=${child_repo_branch}

        echo "Will Clone Branch: ${CLONE_REF}";

    else

        CLONE_REF=$(git ls-remote --tags --sort=-v:refname ${child_repo_host}/${child_repo_user}/${child_repo_name} | sed 's#.*/##' | grep -v '\^{}' | head -n 1)

        echo "Latest tag found: ${CLONE_REF}";

    fi

    git clone --branch "${CLONE_REF}" --depth=1 ${child_repo_host}/${child_repo_user}/${child_repo_name} ${HOME_DIR}/artifacts/${child_repo_user}/${child_repo_name};

    echo "Finished cloning: ${CLONE_REF}";

    cd ${HOME_DIR}/artifacts/${child_repo_user}/${child_repo_name};

    if [ -n "${template_repo}" ]; then

        echo "Adding docs template to: ${child_repo_user}/${child_repo_name}";

        cp -afr ${HOME_DIR}/docs_template/. ${HOME_DIR}/artifacts/${child_repo_user}/${child_repo_name}/docs_template/;

    fi

    git submodule update --init;

    echo "Start Build";

    build "--strict";

    echo "  Finished Build";

    cd ${HOME_DIR};

    echo "Moving Build to Artifacts dir";

    mv ${HOME_DIR}/artifacts/${child_repo_user}/${child_repo_name}/build ${HOME_DIR}/artifacts/${child_repo_user}_${child_repo_name};

    echo "  Finished Move.";

}

merge_child() {

    docs_path="$1"
    repo_user="$2"
    repo_name="$3"

    echo "Begin Merging Child: ${docs_path}";

    echo "Clean site docs: docs/${docs_path}/";

    # rm -rf ${HOME_DIR}/docs/${docs_path}/*;

    cp -afr ${HOME_DIR}/artifacts/${child_repo_user}/${child_repo_name}/docs/${docs_path}/. ${HOME_DIR}/${MKDOCS_SRC_DIRECTORY}/${docs_path}/

    echo "Merge Child Docs: docs/${docs_path}/";

    cp -afr ${HOME_DIR}/artifacts/${child_repo_user}_${child_repo_name}/${docs_path}/. ${HOME_DIR}/artifacts/pages/${docs_path}/;

}


if [ -n "${IS_BUILD}" ]; then


    echo "Commencing Building and Merging Docs";

    build "--strict";

    cp -a ${HOME_DIR}/build/. ${HOME_DIR}/artifacts/pages/;


    if [ -f ".centurion/child_docs.yaml" ]; then


        yq -r '.child_docs[] | @json' .centurion/child_docs.yaml |
        while IFS= read -r obj; do

            name=$(printf '%s\n' "$obj" | yq -r '.name' | envsubst)
            user=$(printf '%s\n' "$obj" | yq -r '.user' | envsubst)
            host=$(printf '%s\n' "$obj" | yq -r '.host' | envsubst)
            path=$(printf '%s\n' "$obj" | yq -r '.path' | envsubst)
            branch=$(printf '%s\n' "$obj" | yq -r '.branch // ""' | envsubst)

            build_child \
                ${host} \
                ${user} \
                ${name} \
                ${branch};


            merge_child \
                ${path} \
                ${user} \
                ${name};


            echo "Clean: ${HOME_DIR}/artifacts/${user}/${name}";

            rm -rf ${HOME_DIR}/artifacts/${user}/${name};

        done

    echo "Rebuild for Search and sitemap";

    build;

    echo "Update Search index";

    cp -a ${HOME_DIR}/build/search/. ${HOME_DIR}/artifacts/pages/search/;

    #
    # Dont update sitemap as the dates are wrong
    #
    # echo "Update Sitemap";

    # cp -a ${HOME_DIR}/build/sitemap.xml.gz ${HOME_DIR}/artifacts/pages/sitemap.xml.gz;

    # cp -a ${HOME_DIR}/build/sitemap.xml ${HOME_DIR}/artifacts/pages/sitemap.xml;

    echo "Copy Source docs";

    cp -a ${HOME_DIR}/${MKDOCS_SRC_DIRECTORY}/. ${HOME_DIR}/artifacts/source/;

    fi


fi

