# build-and-publish-to-pypi

This is a [composite GitHub Action](https://docs.github.com/en/actions/creating-actions/creating-a-composite-action) for building a pure-Python package and publishing it to the [Python Package Index (PyPI)](https://pypi.org).

This actions rolls into a single step two tasks that are commonly run together:

1. Build a Python package's distribution
2. Upload the distribution to PyPI, using PyPI's [trusted publishers](https://docs.pypi.org/trusted-publishers/) mechanism. **New in v2: using trusted publishers is required. Use v1 for the legacy account token authentication method.**

Both actions are done with [uv](https://docs.astral.sh/uv/).

> [!NOTE]
> Packages are built using the `--no-sources` option as recommended by the [uv documentation](https://docs.astral.sh/uv/guides/package/#building-your-package) to ensure that uv-specific configuration is not required.
> Packages must be compatible with PEP 517, which means they must have a `pyproject.toml` file that specifies the build backend in a `[build-system]` section ([see setuptools' tutorial on this](https://setuptools.pypa.io/en/latest/build_meta.html)).

> [!WARNING]
> **Building wheels for multiple platforms is not supported by this action.**
> If your package compiles extensions, you'll need to build your own multi-platform GitHub Actions job that builds a wheel on each platform.

## Usage

There are three steps for implementing this action: set up a trusted publisher on PyPI, set up the GitHub Actions environment, and add this action to your GitHub Actions workflow.

### Step 1. Set up a trusted publisher on PyPI

This action uses PyPI's trusted publisher mechanism.
Start by following the [PyPI documentation](https://docs.pypi.org/trusted-publishers/) to set up a trusted publisher for your PyPI project.
Note in particular the name of the environment and the workflow file.
In the example below, the environment is `pypi`.
The workflow file should match where the YAML workflow file name in your repository.

### Step 2. Set up the GitHub Actions environment

In your repository's settings, create a GitHub Actions [environment](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment).
The name of this environment must match the name your specified to PyPI.

If desired, enable "required reviewers" so that only trusted members or teams can publish to PyPI.

> [!NOTE]
> If you are considering adding a branch restriction, be aware that the PyPI deployment (as recommended in the workflow below) is done in the context of a tag ref, not a branch like `main`.
> Branch restrictions will not work in this case.

### Step 3. Add this action to your GitHub Actions workflow

Next, modify the GitHub Actions workflow file in your repository to include this action:

```yaml
name: Python CI

"on":
  push: {}
  pull_request: {}
  release:
    types: [published]

jobs:
  pypi-publish:
    name: Upload release to PyPI
    runs-on: ubuntu-latest
    environment:
      name: pypi
      url: https://pypi.org/p/<your-pypi-project-name>
    permissions:
      id-token: write
    if: github.event_name == 'release' && github.event.action == 'published'

    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0 # full history for setuptools_scm

      - name: Build and publish
        uses: lsst-sqre/build-and-publish-to-pypi@v3
```

> [!NOTE]
> - This workflow file must match the name of the workflow file you specified in PyPI as the trusted publisher workflow file.
> - Remember to set the `url` in the `environment` section to your PyPI project's URL.
> - Ensure the environment's `name` matches the name of the environment you specified in PyPI.
> - We recommend using GitHub Releases to trigger a PyPI release. To do this, include the `release` event with a type of `published` in the workflow's `on` section.
>   In the job's `if` section, check that the event is a release publication.
>   See _Dry-run mode for package validation_ below for how to run this action in a general Pull Request workflow without publishing to PyPI.
> - To pin the version of uv used for building and uploading, set [required-version in `pyproject.toml`](https://docs.astral.sh/uv/reference/settings/#required-version).

## Action reference

### Inputs

- `upload` (boolean, optional) a flag to enable PyPI uploads. Default is `true`.
  If `false`, the action still performs the package build to catch any build errors but skips the upload to PyPI.
- `working-directory` (string, optional) the directory containing the package to build and publish. Default is `.`.

### Outputs

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

  pypi-publish:
    runs-on: ubuntu-latest
    needs: [lint, test, docs]
```

### Dry-run mode for package validation

You only want to publish to PyPI in a release event, which is typically for GitHub Release publication or tag pushes.
You can still run this action in a general Pull Request workflow, however, to test and validate the package build without uploading to PyPI.
See how the `upload` parameter can be toggled off for non-release events:

```yaml
name: Python CI

"on":
  push: {}
  pull_request: {}
  release:
    types: [published]

jobs:
  test-package:
    name: Test PyPI package build
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0 # full history for setuptools_scm

      - name: Build and publish
        uses: lsst-sqre/build-and-publish-to-pypi@v3
        with:
          upload: "false"

  pypi-publish:
    name: Upload release to PyPI
    runs-on: ubuntu-latest
    environment:
      name: pypi
      url: https://pypi.org/p/<your-pypi-project-name>
    permissions:
      id-token: write
    if: github.event_name == 'release' && github.event.action == 'published'

    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0 # full history for setuptools_scm

      - name: Build and publish
        uses: lsst-sqre/build-and-publish-to-pypi@v3
```

The `test-package` job will run on all events, but the `pypi-publish` job will only run on release events.
Since `test-package` doesn't perform an upload to PyPI, it should not include the `pypi` environment.

### Releasing on a tag push

Instead of using GitHub Releases, you can also trigger a PyPI release on a tag push.
This changes the `on` section of the workflow, as well as the conditional for the `pypi-publish` job:

```yaml
name: Python CI

"on":
  push:
    tags:
      - "*"
  pull_request: {}

jobs:
  pypi-publish:
    name: Upload release to PyPI
    runs-on: ubuntu-latest
    environment:
      name: pypi
      url: https://pypi.org/p/<your-pypi-project-name>
    permissions:
      id-token: write
    if: github.event_name == 'push' && startsWith(github.ref, 'refs/tags/')

    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0 # full history for setuptools_scm

      - name: Build and publish
        uses: lsst-sqre/build-and-publish-to-pypi@v3
```

## Developer guide

This repository provides a **composite** GitHub Action, a type of action that packages multiple regular actions into a single step.
We do this to make the GitHub Actions of all our software projects more consistent and easier to maintain.
[You can learn more about composite actions in the GitHub documentation.](https://docs.github.com/en/actions/creating-actions/creating-a-composite-action)

Create new releases using the GitHub Releases UI and assign a tag with a [semantic version](https://semver.org), including a `v` prefix. Choose the semantic version based on compatibility for users of this workflow. If backwards compatibility is broken, bump the major version.

When a release is made, a new major version tag (i.e. `v1`, `v2`) is also made or moved using [nowactions/update-majorver](https://github.com/marketplace/actions/update-major-version).
We generally expect that most users will track these major version tags.
