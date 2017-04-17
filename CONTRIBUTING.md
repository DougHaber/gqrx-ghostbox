# Making Contributions to this Project

This is an open-source project and code contributions are welcome and appreciated.

Not all changes proposed will be accepted.  This can happen for a large number of reasons.  Before putting much time into changes it is recommended that you first open an issue discussing your planned changes and get feedback.  The discussions that follow will help increase the chance of the changes being merged into the project and prevent duplicate work from occurring.


## Contribution Guidelines

* By contributing to this project you are certifying that the code you share is written by yourself and that you have full ownership and permissions to share it with the project.  By contributing you are releasing your code under the same license found in the LICENSE file, and that you understand this is irrevocable.  Your changes may update the LICENSE file to add in any appropriate copyright notices.

* All contributions must follow the same styles as the surrounding code.  Spacing and newline usage should be the same as is seen elsewhere, as should naming conventions.  If the surrounding code camel cases variables, then do the same, but if it uses underscores, do that.

* Code should be written in ways that fit in with the existing code base.  For example, an ECMAScript 5 project should use `var` instead of `let`, and a contribution to Perl code that makes use of `print` everywhere shouldn't instead contain usage of `say`.  Contributed code should look like it belongs in the code base, and not like it is written by someone different.

* Changes should be small and generally contain a single feature per change.  Contributions that refactor existing code should be discussed via a GitHub issue first.  Large pull requests are much less likely to be accepted.

* The Git history for your branch should be simple and have commits only as necessary.  If this is not the case, rebasing is recommended.

* Code should be reasonably commented.  If it is not obvious what a block of code does, write comments.

* Always make sure all tests pass, even if the change shouldn't have an effect.  If modified code has tests against it, update the tests as needed.  If the code doesn't have tests but similar code elsewhere does, then it may be helpful to add tests.

* Commit messages should follow [common best practices](https://chris.beams.io/posts/git-commit/) and look similar to other commit messages for the project in style.


## Contribution Process

1. If a change is going to be notable, time consuming, or involve refactoring of existing code, first open a GitHub issue and describe the change you plan on making.

2. Fork the repository.  It is recommended that you create a new branch for your changes.

3. Make your changes and when they are fully ready make sure your fork is up to date with the master branch of the official repository.  This is necessary so that it is possible to merge without conflicts.

4. When the change is fully ready, open a pull request.  In the pull request's description, describe the change, why it is being made, and any other helpful information.


Once a pull request is made, the next step is to wait for a response from a project maintainer.  Other users may also provide feedback and try out the changes.

Project maintainers may respond with change requests and other feedback.  When ready, they may choose to merge the contribution into the project.  Depending on the project and its activity it still may take some time before an official release is made containing the changes.
