module.exports = {
    baseBranches: [
        "master"
    ],
    rebaseWhen: "conflicted",
    labels: [
        "dependencies"
    ],
    repositories: [
        "cogitri/charts"
    ],
    username: "renovate-release",
    gitAuthor: "Renovate Bot <bot@renovateapp.com>",
    onboarding: false,
    platform: "github",
    automergeStrategy: "merge-commit",
};
