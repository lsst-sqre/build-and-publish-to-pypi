# build-and-publish-to-pypi

This is a [composite GitHub Action](https://docs.github.com/en/actions/creating-actions/creating-a-composite-action) for building a pure-Python package and publishing it to the [Python Package Index (PyPI)](https://pypi.org).

This actions rolls into a single step two tasks that are commonly run together:

1. Build a Python package's distribution, accomplished with the PyPA's [build](https://pypa-build.readthedocs.io/en/stable/index.html) tool.
2. Upload the distribution to PyPI, using the [pypa/gh-action-pypi-publish](https://github.com/pypa/gh-action-pypi-publish) action, using PyPI's [trusted publishers](https://docs.pypi.org/trusted-publishers/) mechanism. **New in v2: using trusted publishers is required. Use v1 for the legacy account token for PyPI.**

> **Note**
> Since this action uses the [build](https://pypa-build.readthedocs.io/en/stable/index.html) tool, any [PEP 517](https://peps.python.org/pep-0517/)-compatible packaging backend is supported, including [setuptools](https://setuptools.pypa.io/en/latest/).
> You can make your project PEP 517-compatible by adding a `project.toml` file and specifying the build backend in a `[build-system]` section ([see setuptools' tutorial on this](https://setuptools.pypa.io/en/latest/build_meta.html)).
>
> **However, building wheels for multiple platforms is not supported by this action.**
> If your package compiles extensions, you'll need to build your own multi-platform GitHub Actions job that builds a wheel on each platform.

## Usage

```yaml
name: Python CI

"on":
  push: {}
  pull_request: {}
  release:
    types: [published]

jobs:
  pypi:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0 # full history for setuptools_scm

      - name: Build and publish
        uses: lsst-sqre/build-and-publish-to-pypi@v1
        with:
          python-version: "3.10"
          upload: ${{ github.event_name == 'release' && gitub.event.action == 'published' }}
```

Notes:

- We recommend using GitHub Releases to trigger a PyPI release. To do this, include the `release` event with a type of `published` in the workflows `on` section.
  In the `lsst-sqre/build-and-publish-to-pypi`'s `upload` input, check if the event is a release publication. This allows the action to run on other events, such as pushes and pull requests, in a dry-run mode to validate the package build. Releases to PyPI are only performed when the GitHub Release is published.

## Inputs

- `python-version` (string, required) the Python version.
- `upload` (boolean, optional) a flag to enable PyPI uploads. Default is `true`.
  If `false`, the action skips the upload to PyPI, but also runs additional pre-flight validation with [`twine check`](https://twine.readthedocs.io/en/stable/index.html#twine-check).
- `working-directory` (string, optional) the directory containing the package to build and publish. Default is `.`.

## Outputs

No outputs.

## Usage tips

### Using this action with job dependencies

Typically, you'll want to run the PyPI upload _after_ doing any tests.
In that case, add a `needs` field listing those other jobs:

```yaml
jobs:
  lint:
    {}
    # ...

  test:
    {}
    # ...

  docs:
    {}
    # ...

  pypi:
    runs-on: ubuntu-latest
    needs: [lint, test, docs]
```

## Developer guide

This repository provides a **composite** GitHub Action, a type of action that packages multiple regular actions into a single step.
We do this to make the GitHub Actions of all our software projects more consistent and easier to maintain.
[You can learn more about composite actions in the GitHub documentation.](https://docs.github.com/en/actions/creating-actions/creating-a-composite-action)

Create new releases using the GitHub Releases UI and assign a tag with a [semantic version](https://semver.org), including a `v` prefix. Choose the semantic version based on compatibility for users of this workflow. If backwards compatibility is broken, bump the major version.

When a release is made, a new major version tag (i.e. `v1`, `v2`) is also made or moved using [nowactions/update-majorver](https://github.com/marketplace/actions/update-major-version).
We generally expect that most users will track these major version tags.
