# Automatic Testing

The `QED.jl` package and all sub package uses [Continuous integration](https://en.wikipedia.org/wiki/Continuous_integration) (CIs) for running automatic tests. Each time, if a pull request will be open or a commit was pushed to an open pull request, the CI will be triggered and starts a test script. The result of the tests will be reported in the pull request. We distinguish between two kinds of tests:

- **unit tests**: Tests the functionally of the modified (sub) package. The test can ether run standalone or uses functionality of other (third party) packages. 
- **integration tests**: Test all sub packages, which are depend of the modified package are still working with the modifications. For example, if package A is dependent on package B and you change package B, it will be automatically test, if package A is working with the modified package B.

The CI execute first the unit tests. If all unit tests are fine, the integration tests will be started. You can find more information about the unit and integration tests in the next sections.

Our CI uses [GitLab CI](https://docs.gitlab.com/ee/ci/) because it allows us to use CI resources provided by [HIFIS](https://www.hifis.net/). The resources contains a lot of strong CPU runners and also some special runners, like Nvidia and AMD GPUs.

# Unit Test for CI Users

TODO: Coming if implemented.

# Integration Test for CI Users

The integration tests are automatically starting, if you open an pull request and the unit tests passes the CI. The integration tests are in an extra stage in the CI. 

![CI pipeline with unit and integration tests](CI_pipeline.png)

If the tests passes successful, you don't need to do something. If the fails, you have two options.

1. You can solve the problem, by changing the code of the modified (sub) package. The workflow is the same, like fixing unit tests.
2. You need to modify the package, which failed in the integration test. The following text describes, how do you provide the necessary code modification and makes the CI passing the tests and get ready to merge. 

For better understanding, we name the package, which is modified via pull request `orig` and the package, which is depend on it `dep`.  First you should fork and open an new feature branch of the package `dep`. Develop an fix for `dep` on the feature branch, push it to GitHub and open an pull request. By default, the unit test should fail, because the CI needs to use the modified version of `orig`. The solution for the problem is explained in section [Unit Test for CI Users](#Unit-Test-for-CI-Users). Develop at the fix until the CI of `dep` passes all tests. Then go back to the pull request of `orig`. You need to tell the CI, that the integration tests should use your fix for package `dep`. You tell the CI the information about the Git commit message on the last commit of the branch. Therefore you need to add a new line with the following shape to the commit message: 

```
CI_INTG_PKG_URL_<dep_name>: https://github.com/<user>/<dep_name>#<commit_hash>
```

You find the names of the environment variables in the dict `package_infos` in the [jobGenerator/src/jobGenerator.jl](https://github.com/SimeonEhrig/GitlabCIMain/blob/master/jobGenerator/src/jobGenerator.jl). For an example let's assume the name of the `dep` package is `dep1.jl`, `user1` forked the package and the commit hash of the fix for package `dep1.jl` is `45a723b`. And example message could look like:

```
This commit extends function foo with a new
function argument.

The function argument is required to control
the new functionality.

If you pass an 0, it has a special meaning.

CI_INTG_PKG_URL_DEP1JL: https://github.com/user1/dep1.jl#45a723b
```

It is also possible to set a custom URL for more than one package, who is depend on `orig`. Simple add an additional line with the shape of `CI_INTG_PKG_URL_<dep_name>: https://github.com/<user>/<dep_name>#<commit_hash>` to the commit message.

!!! note

    You don't need to add a new commit to set custom URLs. You can modify the commit message with `git commit --amend` and force push to the branch. This also starts the CI pipeline again.


# Integration Test for CI Develops

This section explains how the integration tests are created and executed. It is not mandatory to read the section, if you only want to use the CI. The following figure shows the stages of the CI pipeline:

![detailed CI pipeline of the integration tests](integration_jobs_pipeline.svg)

All of the following stages are executed in the CI pipeline of the sub package, where the code is modified. This means also, that GitLab CI automatically checkouts the repository with the changes of the Pull Request and provide it in the CI job. For easier understanding of the documentation, we name the package `orig`.

- **Stage: Integration Tests**: Execute the unit tests of `orig` via `Pkg.test()`.
- **Stage: Generate integration Tests**: Download the `jobGenerator.jl` script from the `QED.jl` package via `git clone`. The script is executed with the name of the sub package `orig`. The script traverse the dependency tree of the `QED.jl` and it is searching for sub packages which has an dependency of package `orig`. For each package with the dependency of package `orig`, the generator generates a job yaml. By default, it use the upstream repository and development branch of the package tested in the integration test. The repository and commit can be changed via environment parameter in the git commit message. The `jobGenerator.jl` uses the `Package.toml` of the `QED.jl` package because all sub packages are direct and indirect dependencies of it.
- **Stage: Run Integration Tests**: This stage uses the generated job yaml to create and run new tests jobs. It uses the [GitLab CI child pipeline](https://about.gitlab.com/blog/2020/04/24/parent-child-pipelines/#dynamically-generating-pipelines) mechanism.
- **Stage: Integration Tests of Sub package N**: Each job clones the repository of the sub package. After the clone, it use the Julia function `Pkg.develop(path="$CI_package_DIR")` to replaced the dependency to the package `orig` with the modified version of the Pull Request and execute the tests of the sub package via `Pkg.test()`.

!!! note

    If a sub package triggers integration test, the main package `QED.jl` is passive. It does not get any notification or triggers any script. The repository is simply cloned.
