
ARG ALPINE_VERSION=3.23
ARG PYTHON_VERSION=3.11

FROM python:${PYTHON_VERSION}-alpine${ALPINE_VERSION} AS build


# RUN apk add --update \
#     git;
#     # gcc \
#     # cmake \
#     # libc-dev \
#     # alpine-sdk \
#     # libffi-dev \
#     # build-base;


COPY requirements.txt /tmp/requirements.txt

COPY /website-template /website-template


RUN mkdir -p /tmp/python_modules /tmp/python_builds


RUN pip install --upgrade \
        setuptools \
        wheel \
        setuptools-rust \
        build \
        twine; \
    cd /tmp/python_modules; \
    cat /tmp/requirements.txt; \
    pip download --dest . --check-build-dependencies \
        -r /tmp/requirements.txt; \
    python -m build -w -o . /website-template/custom-plugins/*;


RUN cd /tmp/python_modules; \
    ls -la /tmp/python_modules; \
    pip wheel --wheel-dir /tmp/python_builds --find-links . *.whl; \
    pip wheel --wheel-dir /tmp/python_builds --find-links . *.tar.gz || true; \
    ls -la /tmp/python_builds



FROM python:${PYTHON_VERSION}-alpine${ALPINE_VERSION}


COPY --from=build /tmp/python_builds /tmp/python_builds


COPY includes/ /


RUN apk update --no-cache; \
    apk upgrade --no-cache; \
    apk add --no-cache \
        bash \
        envsubst \
        git \
        npm \
        yq; \
    pip install --no-cache-dir /tmp/python_builds/*.*; \
    rm -rf /tmp/python_builds; \
    chmod +x /entrypoint.sh; \
    npm install \
        markdownlint-cli2@v0.18.1 \
        markdownlint-cli2-formatter-junit \
        markdownlint-cli2-formatter-template \
        --global;

RUN git config --global --add safe.directory '*'

ENTRYPOINT ["/entrypoint.sh"]
