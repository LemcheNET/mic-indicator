# Contributing

## Developer Certificate of Origin

All commits must carry a `Signed-off-by` trailer certifying the
[DCO 1.1](https://developercertificate.org/). Add it with:

```bash
git commit -s
```

Forgot? Fix a branch with `git rebase --signoff origin/main` and force-push.

## Workflow

`main` is protected: open a pull request; DCO, ShellCheck, CodeQL, secret scan and
SonarCloud checks must pass.

## Releases

Every merge to `main` runs the release workflow. If `KPlugin.Version` in
`package/metadata.json` has no matching `vX.Y.Z` tag, a GitHub release is created
with a `.plasmoid` artifact, checksums and build provenance. Bump the version in
your PR to ship a release.
