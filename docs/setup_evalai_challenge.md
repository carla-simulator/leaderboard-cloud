# 1) Create a template from the EvalAI-Starters repo

# 2) Create a new challenge branch

# 3) Link the repo and the EvalAI user

Go to *github/host_config.json* and fill the empty fields

# 4) Remove github dependencies

EvalAI-Starters is prepared to automatically create issues when the challenge upload failed, or add PR comments, but that is in general unnecessary, as github Actions can already be used to check that information without cluterring the repository.

At *github/challenge_processing_script.py*, remove:
- the imports *add_pull_request_comment*, *check_if_merge_or_commit*, *check_if_pull_request*, *create_github_repository_issue*
- *GITHUB_CONTEXT* and *GITHUB_AUTH_TOKEN*
- Modify the last `if not is_valid` conditional clause by removing all github functions.

At *github/utils.py*, remove the aforementioned 4 functions and the *Github* import

# 5) Change the challenge_config.yaml to match the leaderboard requirements

# 6) Change the remote_challenge_evaluation.py to match the LB requirements (or maybe the evaluation_script/main.py?)